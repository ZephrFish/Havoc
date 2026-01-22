#include <Havoc/Connector.hpp>
#include <Havoc/Havoc.hpp>
#include <QCryptographicHash>
#include <QMap>
#include <QBuffer>

Connector::Connector( Util::ConnectionInfo* ConnectionInfo )
{
    Teamserver   = ConnectionInfo;
    Socket       = new QWebSocket();
    auto Server  = "wss://" + Teamserver->Host + ":" + this->Teamserver->Port + "/havoc/";
    auto SslConf = Socket->sslConfiguration();

    /* Debug logging for connection troubleshooting */
    if ( HavocX::DebugMode ) {
        spdlog::debug( "[CONNECT] Initializing connection to teamserver" );
        spdlog::debug( "[CONNECT] Target: {}", Server.toStdString() );
        spdlog::debug( "[CONNECT] Host: {}, Port: {}", Teamserver->Host.toStdString(), Teamserver->Port.toStdString() );
        spdlog::debug( "[CONNECT] User: {}", Teamserver->User.toStdString() );
    }

    /* ignore annoying SSL errors */
    SslConf.setPeerVerifyMode( QSslSocket::VerifyNone );
    Socket->setSslConfiguration( SslConf );
    Socket->ignoreSslErrors();

    QObject::connect( Socket, &QWebSocket::binaryMessageReceived, this, [&]( const QByteArray& Message )
    {
        if ( HavocX::DebugMode ) {
            spdlog::debug( "[CONNECT] Received {} bytes from teamserver", Message.size() );
        }

        auto Package = HavocSpace::Packager::DecodePackage( Message );

        if ( Package != nullptr )
        {
            if ( ! Packager )
                return;

            Packager->DispatchPackage( Package );

            return;
        }

        spdlog::critical( "Got Invalid json" );
    } );

    QObject::connect( Socket, &QWebSocket::connected, this, [&]()
    {
        if ( HavocX::DebugMode ) {
            spdlog::debug( "[CONNECT] WebSocket connected successfully" );
            spdlog::debug( "[CONNECT] Sending authentication request" );
        }

        this->Packager = new HavocSpace::Packager;
        this->Packager->setTeamserver( this->Teamserver->Name );

        SendLogin();
    } );

    QObject::connect( Socket, &QWebSocket::disconnected, this, [&]()
    {
        if ( HavocX::DebugMode ) {
            spdlog::debug( "[CONNECT] WebSocket disconnected" );
            spdlog::debug( "[CONNECT] Error string: {}", Socket->errorString().toStdString() );
            spdlog::debug( "[CONNECT] Error code: {}", Socket->error() );
        }

        MessageBox( "Teamserver error", Socket->errorString(), QMessageBox::Critical );

        Socket->close();

        Havoc::Exit();
    } );

    /* Add state change monitoring for debug */
    if ( HavocX::DebugMode ) {
        QObject::connect( Socket, &QWebSocket::stateChanged, this, [&]( QAbstractSocket::SocketState state )
        {
            const char* stateStr = "Unknown";
            switch ( state ) {
                case QAbstractSocket::UnconnectedState: stateStr = "Unconnected"; break;
                case QAbstractSocket::HostLookupState: stateStr = "HostLookup"; break;
                case QAbstractSocket::ConnectingState: stateStr = "Connecting"; break;
                case QAbstractSocket::ConnectedState: stateStr = "Connected"; break;
                case QAbstractSocket::BoundState: stateStr = "Bound"; break;
                case QAbstractSocket::ClosingState: stateStr = "Closing"; break;
                case QAbstractSocket::ListeningState: stateStr = "Listening"; break;
            }
            spdlog::debug( "[CONNECT] WebSocket state changed: {}", stateStr );
        } );

        QObject::connect( Socket, &QWebSocket::errorOccurred, this, [&]( QAbstractSocket::SocketError error )
        {
            spdlog::debug( "[CONNECT] WebSocket error occurred: {} - {}", error, Socket->errorString().toStdString() );
        } );

        QObject::connect( Socket, &QWebSocket::sslErrors, this, [&]( const QList<QSslError>& errors )
        {
            spdlog::debug( "[CONNECT] SSL errors detected (ignored):" );
            for ( const auto& err : errors ) {
                spdlog::debug( "[CONNECT]   - {}", err.errorString().toStdString() );
            }
        } );

        QObject::connect( Socket, &QWebSocket::bytesWritten, this, [&]( qint64 bytes )
        {
            spdlog::debug( "[CONNECT] Sent {} bytes to teamserver", bytes );
        } );

        QObject::connect( Socket, &QWebSocket::pong, this, [&]( quint64 elapsedTime, const QByteArray& payload )
        {
            spdlog::debug( "[CONNECT] Pong received - elapsed time: {} ms, payload size: {}", elapsedTime, payload.size() );
        } );
    }

    if ( HavocX::DebugMode ) {
        spdlog::debug( "[CONNECT] Opening WebSocket connection to: {}", Server.toStdString() );
    }

    Socket->open( QUrl( Server ) );
}

bool Connector::Disconnect()
{
    if ( this->Socket != nullptr )
    {
        this->Socket->disconnect();
        return true;
    }

    return false;
}

Connector::~Connector() noexcept
{
    delete this->Socket;
}

void Connector::SendLogin()
{
    Util::Packager::Package Package;

    Util::Packager::Head_t Head;
    Util::Packager::Body_t Body;

    Head.Event              = Util::Packager::InitConnection::Type;
    Head.User               = this->Teamserver->User.toStdString();
    Head.Time               = CurrentTime().toStdString();

    Body.SubEvent           = Util::Packager::InitConnection::Login;
    Body.Info[ "User" ]     = this->Teamserver->User.toStdString();
    Body.Info[ "Password" ] = QCryptographicHash::hash( this->Teamserver->Password.toLocal8Bit(), QCryptographicHash::Sha3_256 ).toHex().toStdString();

    Package.Head = Head;
    Package.Body = Body;

    if ( HavocX::DebugMode ) {
        spdlog::debug( "[CONNECT] Sending login package for user: {}", Head.User );
        spdlog::debug( "[CONNECT] Password hash (SHA3-256): {}", Body.Info[ "Password" ] );
        spdlog::debug( "[CONNECT] Event type: {}, SubEvent: {}", Head.Event, Body.SubEvent );
    }

    SendPackage( &Package );
}

void Connector::SendPackage( Util::Packager::PPackage Package )
{
    auto jsonData = Packager->EncodePackage( *Package ).toJson( QJsonDocument::Compact );

    if ( HavocX::DebugMode ) {
        spdlog::debug( "[CONNECT] Sending package: {} bytes", jsonData.size() );
        spdlog::debug( "[CONNECT] Package Event: {}, SubEvent: {}", Package->Head.Event, Package->Body.SubEvent );
    }

    Socket->sendBinaryMessage( jsonData );
}
