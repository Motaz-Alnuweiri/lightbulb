/********************************************************************

src/xmpp/XmppConnectivity.h
-- used for managing XMPP clients and serves as a bridge between UI and
-- clients

Copyright (c) 2013 Maciej Janiszewski

This file is part of Lightbulb.

Lightbulb is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

*********************************************************************/

#ifndef XMPPCONNECTIVITY_H
#define XMPPCONNECTIVITY_H

#include <QObject>
#include <QThread>
#include <QMap>
#include "src/models/AccountsItemModel.h"
#include "MyXmppClient.h"
#include "src/database/DatabaseWorker.h"
#include "src/cache/MyCache.h"
#include "src/database/Settings.h"

#include "MessageWrapper.h"

#include "src/models/ChatsListModel.h"
#include "src/models/MsgListModel.h"
#include "src/models/MsgItemModel.h"

class XmppConnectivity : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MyXmppClient* client READ getClient NOTIFY accountChanged)
    Q_PROPERTY(RosterListModel* roster READ getRoster NOTIFY rosterChanged)
    Q_PROPERTY(ChatsListModel* chats READ getChats NOTIFY chatsChanged)
    Q_PROPERTY(int page READ getPage WRITE gotoPage NOTIFY pageChanged)
    Q_PROPERTY(int messagesCount READ getMessagesCount NOTIFY pageChanged)
    Q_PROPERTY(SqlQueryModel* messagesByPage READ getSqlMessagesByPage NOTIFY pageChanged)
    Q_PROPERTY(SqlQueryModel* messages READ getSqlMessagesByPage NOTIFY sqlMessagesChanged)
    Q_PROPERTY(MsgListModel* cachedMessages READ getMessages NOTIFY sqlMessagesChanged)
    Q_PROPERTY(QString chatJid READ getChatJid WRITE setChatJid NOTIFY chatJidChanged)
    Q_PROPERTY(QString currentAccount READ getCurrentAccount WRITE changeAccount NOTIFY accountChanged)
    Q_PROPERTY(QString currentAccountName READ getCurrentAccountName NOTIFY accountChanged)
    Q_PROPERTY(int messagesLimit READ getMsgLimit WRITE setMsgLimit NOTIFY msgLimitChanged )
public:
    explicit XmppConnectivity(QObject *parent = 0);
    ~XmppConnectivity();

    bool initializeAccount(QString index, AccountsItemModel* account);
    Q_INVOKABLE void changeAccount(QString GRID);
    QString getCurrentAccount() { return currentClient; }

    // well, this stuff is needed
    int getPage() const { return page; }
    void gotoPage(int nPage);

    QString getChatJid() const { return currentJid; }
    void setChatJid( const QString & value ) {
        if(value!=currentJid) {
            currentJid=value;
            emit chatJidChanged();
        }
    }

    /* --- diagnostics --- */
    Q_INVOKABLE bool dbRemoveDb();
    Q_INVOKABLE bool cleanCache();
    Q_INVOKABLE bool resetSettings();

    //
    Q_INVOKABLE QString generateAccountName(QString host,QString jid);
    Q_INVOKABLE QString getAccountName(QString grid);
    Q_INVOKABLE QString getAccountIcon(QString grid);

    // widget
    void addChat(QString account, QString bareJid) {
      removeChat(account,bareJid,true);
      latestChats.append(account+";"+bareJid);
      if (latestChats.count()>10) latestChats.removeFirst();
      emit widgetDataChanged();
    }

    void removeChat(QString account, QString bareJid,bool silent=false) {
      if (latestChats.contains(account+";"+bareJid))
        latestChats.removeAt(latestChats.indexOf(account+";"+bareJid));
      if (!silent) emit widgetDataChanged();
    }

    Q_INVOKABLE QString getChatPresence(int index) {
      if (latestChats.count() >= latestChats.count()-index && latestChats.count()-index >= 0) {
        QString presenceJid = latestChats.at(latestChats.count()-index);
        return clients->value(presenceJid.split(';').at(0))->getPropertyByJid(presenceJid.split(';').at(1),"presence");
        } else return "-2";
    }

    Q_INVOKABLE QString getChatName(int index,bool showUnreadCount) {
      if (latestChats.count() >= latestChats.count()-index && latestChats.count()-index >= 0) {
        QString bareJid = latestChats.at(latestChats.count()-index);
        QString name;

        if (showUnreadCount) {
            name = "[" + clients->value(bareJid.split(';').at(0))->getPropertyByJid(bareJid.split(';').at(1),"unreadMsg") + "] ";
            if (name == "[0] ") name = "";
        }

        name += clients->value(bareJid.split(';').at(0))->getPropertyByJid(bareJid.split(';').at(1),"name");
        return name;
      } else return "";
    }

signals:
    void accountChanged();
    void rosterChanged();

    void pageChanged();
    void sqlMessagesChanged();
    void chatJidChanged();

    void chatsChanged();

    void notifyMsgReceived(QString name,QString jid,QString body);

    void qmlChatChanged();
    void msgLimitChanged();

    void widgetDataChanged();
    
public slots:
    void changeRoster() {
        roster = selectedClient->getCachedRoster();
        emit rosterChanged();
    }
    void updateContact(QString m_accountId,QString bareJid,QString property,int count) {
        dbWorker->executeQuery(QStringList() << "updateContact" << m_accountId << bareJid << property << QString::number(count));
    }
    void updateMessages() { dbWorker->updateMessages(currentClient,currentJid,page); }
    void insertMessage(QString m_accountId,QString bareJid,QString body,QString date,int mine);

    Q_INVOKABLE QString getAvatarByJid(QString bareJid) { return lCache->getAvatarCache(bareJid); }

    // handling chats list
    void chatOpened(QString accountId,QString bareJid);
    void chatClosed(QString accountId,QString bareJid);
    Q_INVOKABLE QString getPropertyByJid(QString account,QString property,QString jid);
    Q_INVOKABLE QString getPreservedMsg(QString jid);
    Q_INVOKABLE void preserveMsg(QString jid,QString message);

    Q_INVOKABLE void setMsgLimit(int limit) {
      msgLimit = limit;
    }

    int getMsgLimit() { return msgLimit; }

    Q_INVOKABLE void emitQmlChat() {
      emit qmlChatChanged();
      emit sqlMessagesChanged();
    }

    // handling clients
    void accountAdded(QString id);
    Q_INVOKABLE void accountRemoved(QString id);
    void accountModified(QString id);

    Q_INVOKABLE void setAccountData( QString _grid, QString _name, QString _icon, QString _jid, QString _pass, bool connectOnStart, QString _resource = "",
                                     QString _host = "", QString _port = "", bool manuallyHostPort = false ) {
      qDebug() << "XmppConnectivity::setAccountData(): setting account data for" << qPrintable(_jid);
      lSettings->setAccount(_grid, _name, _icon, _jid,_pass,connectOnStart,_resource,_host,_port,manuallyHostPort);
    }

    Q_INVOKABLE int getStatusByIndex(QString accountId);
    void renameChatContact(QString bareJid,QString name) {
      ChatsItemModel* item = (ChatsItemModel*)chats->find(bareJid);
      if (item != 0) item->setContactName(name);
      item = 0; delete item;
    }

    Q_INVOKABLE void closeChat(QString accountId, QString bareJid) { clients->value(accountId)->closeChat(bareJid); }
    Q_INVOKABLE void closeChat(QString bareJid) { clients->value(currentClient)->closeChat(bareJid); }
    Q_INVOKABLE void resetUnreadMessages(QString accountId, QString bareJid) { clients->value(accountId)->resetUnreadMessages(bareJid); }
    Q_INVOKABLE void resetUnreadMessages(QString bareJid) { clients->value(currentClient)->resetUnreadMessages(bareJid); }

private:
    QString currentClient;
    QMap<QString,MyXmppClient*> *clients;
    MyXmppClient* selectedClient;
    MyXmppClient* getClient() { return selectedClient; }

    QMap<QString,MsgListModel*> *cachedMessages;

    RosterListModel* roster;
    RosterListModel* getRoster() { return roster; }

    QString getCurrentAccountName();

    SqlQueryModel* getSqlMessagesByPage() { return dbWorker->getSqlMessages(); }
    int getMessagesCount() { return dbWorker->getPageCount(currentClient,currentJid); }
    MsgListModel* getMessages() {
      MsgListModel* messages = cachedMessages->value(currentJid);
      if (msgLimit > 0) {
         while (messages->count() > msgLimit) {
             messages->remove(0);
           }
        }
      return messages;
    }

    ChatsListModel* chats;
    ChatsListModel* getChats() { return chats; }

    MyCache* lCache;
    Settings* lSettings;

    DatabaseWorker *dbWorker;
    QThread *dbThread;

    int page; //required for archive view
    QString currentJid;

    static bool removeDir(const QString &dirName); //workaround for qt not able to remove directory recursively
    // http://john.nachtimwald.com/2010/06/08/qt-remove-directory-and-its-contents/

    int globalUnreadCount;
    int msgLimit;

    MessageWrapper *msgWrapper;

    QStringList latestChats;
};

#endif // XMPPCONNECTIVITY_H
