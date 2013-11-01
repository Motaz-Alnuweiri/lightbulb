import QtQuick 1.1
import com.nokia.symbian 1.1
import com.nokia.extras 1.1
import QtMultimediaKit 1.1
import QtMobility.feedback 1.1
import lightbulb 1.0

PageStackWindow {
    id: main

    showStatusBar:                   true
    platformInverted:                settings.gBool("ui","invertPlatform")

    property string textColor:       platformInverted ? platformStyle.colorNormalDark : platformStyle.colorNormalLight

    property int                     globalUnreadCount: 0
    property int                     tempUnreadCount: 0
    property bool                    inputInProgress: false

    property string                  accJid: ""
    property string                  accPass: ""
    property string                  accResource: ""
    property string                  accHost: ""
    property string                  accPort: ""
    property bool                    accManualHostPort: false
    property bool                    accDefault: false

    property int                     splitscreenY: 0

    property string                  lastStatus: settings.gBool("behavior", "lastStatusText") ? settings.gStr("behavior","lastStatusText") : ""
    property string nowEditing:      ""
    property string url:             ""

    signal statusChanged
    property string statStatusText:  xmppClient.statusText
    property int lastUsedStatus: 0
    signal statusTextChanged

    property bool requestMyVCard:    false

    property string dialogTitle:     ""
    property string dialogText:      ""
    property string dialogName:      ""

    property bool notifyHold:  false
    property int notifyHoldDuration: 0

    property int suspenderDuration: 0
    property bool isSuspended: false

    property bool isActive: true

    property bool isChatInProgress: false

    property int blinkerSet: 0

    SymbiosisAPI {
        id: symbiosis
    }

    Timer {
        id: notifyHoldTimer
        interval: 60000
        running: false; repeat: true
        onTriggered: {
            if (notifyHoldDuration>0) {
                notifyHold = true
                notifyHoldDuration--
                console.log(notifyHoldDuration + " minutes left till notifications be resumed.")
            } else {
                notifyHold = false
                notifyHoldTimer.running = false
            }
        }


    }

    Timer {
        id: blinker
        interval: 100
        running: true; repeat:true
        onTriggered: {
            if (globalUnreadCount>0) {
                if (blinkerSet < 4) { avkon.notificationBlink(); /*symbiosis.sendMessage("blink");*/ blinkerSet++ } else { if (blinkerSet > 6) { blinkerSet = 0} else { blinkerSet++ } }
            } else { blinkerSet = 0; blinker.running = false }
        }
    }

    Connections {
        target: Qt.application
        onActiveChanged: {
            if (Qt.application.active) {
                isActive = true
                blinker.running = false
                suspender.running = false
                suspenderDuration = 0
                if (isSuspended) {
                    pageStack.replace("qrc:/pages/Roster")
                    isSuspended = false
                }
                if (xmppClient.chatJid != "") {
                    isChatInProgress = true
                    globalUnreadCount = globalUnreadCount - tempUnreadCount
                }
                tempUnreadCount = 0
                if (globalUnreadCount<0) {
                    globalUnreadCount = 0
                }
            } else {
                isActive = false
                if (globalUnreadCount>0) {
                    blinker.running = true
                }
                suspender.running = true
                isChatInProgress = false
            }
        }
    }

    Timer {
        id: suspender
        running: true; repeat: true
        onTriggered: {
            if (suspenderDuration==60) {
                if (!isSuspended) {
                    pageStack.pop()
                    pageStack.pop()
                    pageStack.clear()
                    isSuspended = true
                    console.log("Suspending...")
                    suspender.running = false
                    if (xmppClient.chatJid != "") {
                        xmppClient.setUnreadMessages(xmppClient.chatJid, tempUnreadCount)
                        xmppClient.chatJid = ""
                        isChatInProgress = false
                        tempUnreadCount = 0
                    }
                }
            } else { suspenderDuration += 1; console.log("Will suspend in "+(60-suspenderDuration)) }
        }

    }

    CommonDialog {
        id: closeDialog
        titleText: "Confirmation"
        buttonTexts: [qsTr("Yes"), qsTr("No")]

        onButtonClicked: {
            if (index === 0) {
                Qt.quit()
            }
        }

        content: Text {
            color: "white";
            id: dialogQueryLabel;
            wrapMode: Text.Wrap;
            anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin:10; verticalCenter: parent.verticalCenter }
            text: qsTr("Are you sure you want to close the app?")
        }
    }

    XmppClient {
        id: xmppClient
        onErrorHappened: {
            if (settings.gBool("behavior", "reconnectOnError")) {
                dialog.source = ""
                dialog.source = "qrc:/dialogs/Status/Reconnect"
            }
        }
        onMessageReceived: {
            if( xmppClient.myBareJid != bareJidLastMsg ) {
                if (!isChatInProgress) {
                    globalUnreadCount++
                    if (bareJidLastMsg == xmppClient.chatJid) {
                        tempUnreadCount++
                    }
                } else {
                        if (bareJidLastMsg != xmppClient.chatJid || !isActive) {
                            globalUnreadCount++
                        }
                }
                if (!isActive) { blinker.running = true }
                if (!notifyHold) {
                    if (settings.gBool("notifications", "usePopupRecv") == true && !isActive) {
                        avkon.showPopup(globalUnreadCount + " unread messages", "New message from "+ getNameByJid(bareJidLastMsg) + ".")
                    }
                    if (settings.gBool("notifications", "wibblyWobblyTimeyWimeyStuff" && !isActive) == true) {
                        avkon.screenBlink()
                    }
                    notifySndVibr("MsgRecv")
                }
                if (settings.gBool("notifications","notifyMsgRecv") == true) {
                    sb.text = "[" + globalUnreadCount + "] " + qsTr("Message from ") + getNameByJid(bareJidLastMsg)
                    sb.open()
                }
                if (settings.gBool("behavior","enableHsWidget")) {
                    notify.postHSWidget()
                }
            }
        }
        onStatusChanged: {
            console.log( "XmppClient::onStatusChanged:" + status )
            main.statusChanged()
            if (!notifyHold) {
                notifySndVibr("NotifyConn")
                if (settings.gBool("notifications", "notifyConnection") == true) {
                    sb.text = qsTr("Status changed to ") + notify.getStatusName()
                    sb.open()
                }
            }
            if (settings.gBool("behavior","enableHsWidget")) {
                notify.postHSWidget()
            }
        }
        onVCardChanged: { xmppVCard.vcard = xmppClient.vcard }
        onPresenceJidChanged: { if (presenceBareJid == xmppClient.myBareJid ) notify.getStatusName(); }
        onSubscriptionReceived: {
            console.log( "QML: Main: ::onSubscriptionReceived: [" + bareJid + "]" )
            if (settings.gBool("notifications","notifySubscription") == true) {
                sb.text = "Subscription request from " + bareJid
                sb.open()
            }
            if (!notifyHold) {
                notifySndVibr("MsgSub")
            }
            dialogJid = bareJid
            dialog.source = ""
            dialog.source = "qrc:/dialogs/Contact/Subscribe"
        }
        onTypingChanged: {
            if (settings.gBool("notifications", "notifyTyping") == true) {
                if (isTyping) {
                    sb.text = getNameByJid(bareJid) + " is typing."
                } else {
                    sb.text = getNameByJid(bareJid) + " stopped typing."
                }
                sb.open()
            }
        }
    } //XmppClient

    MeegIMSettings { id: settings }
    XmppVCard { id: xmppVCard }

    Component.onCompleted: {
        initAccount()
        checkIfFirstRun()
        xmppClient.keepAlive = settings.gInt("behavior", "keepAliveInterval")
        xmppClient.archiveIncMessage = settings.gBool("behavior", "archiveIncMessage")
        if (settings.gBool("behavior","goOnlineOnStart")) { xmppClient.setMyPresence( XmppClient.Online, lastStatus ) }
        pageStack.push("qrc:/pages/Roster")
    }

    function changeAudioFile() {
        var filename = avkon.openFileSelectionDlg();

        if (filename != "") {
            settings.sStr(filename,"notifications",nowEditing+"File")
        }
    }

    /************************( stuff to do when running this app )*****************************/

    function checkIfFirstRun() {
        if (!settings.gBool("main","not_first_run") || settings.gStr("main","last_used_rel") !== "0.2-symbiosis") {
            settings.sBool(true,"main","not_first_run")
            settings.sStr("0.2","main","last_used_rel")

            symbiosis.registerEvent("msgRecv");
            symbiosis.registerEvent("msgSent");
            symbiosis.registerEvent("msgSub");
            symbiosis.registerEvent("notifyConnection");

            symbiosis.setEventProperty("msgRecv","enabled","b_true");

            symbiosis.setEventProperty("msgRecv","vibraEnabled","b_true");
            symbiosis.setEventProperty("msgRecv","vibraDuration","i_800");
            symbiosis.setEventProperty("msgRecv","vibraIntensity","i_100");
            symbiosis.setEventProperty("msgRecv","soundEnabled","b_true");
            symbiosis.setEventProperty("msgRecv","soundFile","s_file:///C:/Data/.config/Lightbulb/sounds/Message_Received.wav");
            symbiosis.setEventProperty("msgRecv","soundVolume","i_100");
            symbiosis.setEventProperty("msgRecv","blink","b_true");
            symbiosis.setEventProperty("msgRecv","discreetPopup","b_true");

            symbiosis.setEventProperty("msgSent","enabled","b_true");

            symbiosis.setEventProperty("msgSent","vibraEnabled","b_true");
            symbiosis.setEventProperty("msgSent","vibraDuration","i_400");
            symbiosis.setEventProperty("msgSent","vibraIntensity","i_100");
            symbiosis.setEventProperty("msgSent","soundEnabled","b_true");
            symbiosis.setEventProperty("msgSent","soundFile","s_file:///C:/Data/.config/Lightbulb/sounds/Message_Sent.wav");
            symbiosis.setEventProperty("msgSent","soundVolume","i_100");

            symbiosis.setEventProperty("msgSub","enabled","b_false");
            symbiosis.setEventProperty("msgSub","vibraEnabled","b_true");
            symbiosis.setEventProperty("msgSub","vibraDuration","i_500");
            symbiosis.setEventProperty("msgSub","vibraIntensity","i_50");

            symbiosis.setEventProperty("msgSub","soundEnabled","b_true");
            symbiosis.setEventProperty("msgSub","soundFile","s_file:///C:/Data/.config/Lightbulb/sounds/Subscription_Request.wav");
            symbiosis.setEventProperty("msgSub","soundVolume","i_100");

            settings.sBool(true,"notifications","notifyConnection")

            settings.sBool(true,"notifications","notifySubscription")

            settings.sBool(true,"notifications","notifyTyping")

            settings.sBool(true,"ui","markUnread")
            settings.sBool(true,"ui","showUnreadCount")
            settings.sInt(75,"ui","rosterItemHeight")
            settings.sBool(true,"ui","showContactStatusText")

            settings.sBool(true,"behavior","reconnectOnError")
            settings.sInt(60,"behavior","keepAliveInterval")

            settings.sBool(true,"behavior","storeStatusText")

            dialogTitle = qsTr("First run")
            dialogText = qsTr("Welcome to Lightbulb! I guess it's your first time, isn't it? Have fun with testing! #whyIevenPutThisDialogHere?")
            notify.postInfo(dialogText)

            pageStack.replace("qrc:/pages/Roster")

        }

    }
    property bool _existDefaultAccount: false
    function initAccount() {
        var accc=0
        _existDefaultAccount = false
        for( var j=0; j<settings.accounts.count(); j++ )
        {
            if( settings.accIsDefault( j ) )
            {
                _existDefaultAccount = true
                xmppClient.myBareJid = settings.accGetJid( j );
                xmppClient.myPassword = settings.accGetPassword( j );
                xmppClient.resource = settings.accGetResource( j );

                if( settings.accIsManuallyHostPort( j ) ) {
                    xmppClient.host = settings.accGetHost( j  );
                } else {
                    xmppClient.host = "";
                }

                if( settings.accIsManuallyHostPort( j ) ) {
                    xmppClient.port = settings.accGetPort( j  );
                } else {
                    xmppClient.port = 0;
                }

                console.log("QML: main::initAccount():" + xmppClient.myBareJid + "/" + xmppClient.resource);
            } else {
                    _existDefaultAccount = true
                    accc++
            }
        }
    }

    /****************************( Dialog windows, menus and stuff)****************************/

    Loader { id: dialog }
    ContextMenu {
        id: linkContextMenu
        MenuLayout {
            MenuItem {text: qsTr("Copy"); onClicked: { clipboard.setText(url) } }
            MenuItem {text: qsTr("Open in default browser"); onClicked: { Qt.openUrlExternally(url) }}
      }
    }
    Clipboard { id: clipboard }

    /**************(* notify *)**************/

    Avkon { id: avkon }

    Notifications { id: notify }

    StatusBar { id: sbar; x: 0; y: -main.y
        Rectangle {
                  anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                  width: sbar.width - 183; height: parent.height
                  clip: true;
                  color: "#00000000"

                  Text{
                      id: statusBarText
                      anchors.verticalCenter: parent.verticalCenter
                      maximumLineCount: 1
                      x: 0
                      color: "white"
                      font.pointSize: 6
                    }
                    Rectangle{
                        width: 25
                        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                        rotation: -90

                        gradient: Gradient{
                            GradientStop { position: 0.0; color: "#00000000" }
                            GradientStop { position: 1.0; color: "#ff000000" }
                        }
                    }
                }
        InfoBanner { id: sb }

    }

    function notifySndVibr(how) {
        if (!notifyHold) {
            if( settings.gBool("notifications","vibra"+how )) {
                hapticsEffect.duration = settings.gInt("notifications","vibra"+how+"Duration" )
                hapticsEffect.intensity = settings.gInt("notifications","vibra"+how+"Intensity" )/100
                hapticsEffect.running = true
            }
            if( settings.gBool("notifications","sound"+how )) {
                sndEffect.source = settings.gStr("notifications","sound"+how+"File" )
                sndEffect.volume = settings.gInt("notifications","sound"+how+"Volume" )/100
                sndEffect.play()
            }
        }
    }
    Audio { id: sndEffect }
    HapticsEffect {
        id: hapticsEffect
        attackIntensity: 0
        attackTime: 250
        fadeTime: 250
        fadeIntensity: 0
        running: false
    }

    /***************( splitscreen input )***************/
    Item {
        id: splitViewInput
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }

        states: [
            State {
                name: "Visible"; when: inputContext.visible
                PropertyChanges { target: splitViewInput; height: inputContext.height }
                PropertyChanges { target: main; inputInProgress: true }
                PropertyChanges { target: main; y: splitscreenY > 0 ? 0-splitscreenY : 0 }
            },
            State {
                name: "Hidden"; when: !inputContext.visible
                PropertyChanges { target: splitViewInput; }
                PropertyChanges { target: main; inputInProgress: false }
            }
        ]
    }


    /***************(uselessshit)**********/
    Rectangle {
        color: "black"
        opacity: 0.5
        anchors.fill: parent

        visible: main.pageStack.busy ? true : false

        BusyIndicator {
            id: busyindicator1
            anchors.centerIn: parent
            running: true
        }

    }

}
