import QtQuick 1.1
import com.nokia.symbian 1.1

Item {
    height: markUnread.height + unreadCount.height + hideOffline.height + showContactStatusText.height + rosterLayout.height + rosterItemHeightText.height + rosterItemHeight.height +  7*content.spacing

    Column {
        id: content
        spacing: 5
        anchors { top: parent.top; topMargin: 10; left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10 }
        CheckBox {
           id: markUnread
           text: qsTr("Mark contacts with unread msg.")
           checked: settings.gBool("ui", "markUnread")
           platformInverted: main.platformInverted
           onCheckedChanged: {
              settings.sBool(checked,"ui", "markUnread")
               if (!checked) {
                   unreadCount.enabled = false;
                   unreadCount.checked = false;
               } else unreadCount.enabled = true;
           }
        }
        CheckBox {
           id: unreadCount
           text: qsTr("Show unread count")
           enabled: markUnread.checked
           checked: settings.gBool("ui", "showUnreadCount")
           platformInverted: main.platformInverted
           onCheckedChanged: {
              settings.sBool(checked,"ui", "showUnreadCount")
           }
        }
        CheckBox {
           id: hideOffline
           text: qsTr("Hide Offline contacts")
           platformInverted: main.platformInverted
           checked: settings.gBool("ui", "hideOffline")
           onCheckedChanged: {
              settings.sBool(checked,"ui", "hideOffline")
           }
        }
        CheckBox {
           id: showContactStatusText
           text: qsTr("Show contacts status text")
           platformInverted: main.platformInverted
           checked: settings.gBool("ui", "showContactStatusText")
           onCheckedChanged: {
              settings.sBool(checked,"ui", "showContactStatusText")
           }
        }
        CheckBox {
           id: rosterLayout
           text: qsTr("Show avatars")
           platformInverted: main.platformInverted
           checked: settings.gBool("ui", "rosterLayoutAvatar")
           onCheckedChanged: {
              settings.sBool(checked,"ui", "rosterLayoutAvatar")
           }
        }
        Text {
            id: rosterItemHeightText
            text: "Roster item height (" + rosterItemHeight.value + " px)"
            color: vars.textColor
        }
        Slider {
                id: rosterItemHeight
                stepSize: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: content.width-20
                maximumValue: 128
                //minimumValue: 24
                value: settings.gInt("ui", "rosterItemHeight")
                orientation: 1
                platformInverted: main.platformInverted

                onValueChanged: {
                    settings.sInt(value,"ui", "rosterItemHeight")
                }
            }
    }
}

