/********************************************************************

src/cache/MyCache.cpp
-- stores VCards and avatars in cache

Copyright (c) 2013 Anatoliy Kozlov, Maciej Janiszewski

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

#include "mycache.h"
#include <QBuffer>
#include <QImageReader>
#include <QFile>
#include <QDebug>

MyCache::MyCache(QObject *parent) : StoreVCard(parent)
{
    pathMeegIMHome = QDir::homePath() + "/" + ".config" + "/" + "Lightbulb";
    pathMeegIMCache = pathMeegIMHome + "/" + QString("cache");

    this->setCachePath( pathMeegIMCache );
}

bool MyCache::createHomeDir() const
{
    bool retValue = false;

    QDir hD( pathMeegIMHome );
    if( hD.exists() == false ) {
        if( ! hD.mkdir(pathMeegIMHome) ) {
            qCritical() << "Error: Cannot create home directory !";
            return retValue;
        }
    }

    QDir cD( pathMeegIMCache );
    if( cD.exists() == false ) {
        if( ! cD.mkdir(pathMeegIMCache) ) {
            qCritical() << "Error: Cannot create cache directory !";
            return retValue;
        }
    }

    retValue = true;

    return retValue;
}


bool MyCache::addCacheJid(const QString &jid)
{
    if( this->existsCacheJid(jid) ) {
        return true;
    }

    QString jidCache = pathMeegIMCache + "\\" + jid;
    QDir jD( jidCache );
    if( ! jD.mkdir(jidCache) ) {
        qCritical() << "Error: Cannot create cache directory: " << jid;
        return false;
    }

    return true;
}

bool MyCache::setAvatarCache(const QString &jid, const QByteArray &avatar) const
{
    if( !(this->existsCacheJid(jid)) ) return false;

    QBuffer buffer;
    buffer.setData( avatar );
    buffer.open(QIODevice::ReadOnly);
    QImageReader imageReader(&buffer);
    QImage avatarImage = imageReader.read();

    QString avatarJid = pathMeegIMCache + "/" + jid + "/" + QString("avatar.png");

    if (avatarImage.size() != QSize(0,0)) {
      if( avatarImage.save(avatarJid) ) {
        qDebug() << "avatar saved properly to" << avatarJid;
        return true;
      } else qDebug() << "brick T_T occured while trying to save avatar to" << avatarJid;
    }
    return false;
}

QString MyCache::getAvatarCache(const QString &jid) const
{
    QString avatarJid = pathMeegIMCache + "/" + jid + "/" + QString("avatar.png");
    if( QFile::exists(avatarJid) ) return "file:///" + avatarJid;

    return "qrc:/avatar";
}
