# RSS Torrent Fetcher

A lightweight Bash script for automatically fetching new torrent files from RSS feeds, logging activity, and optionally sending notifications to Discord.

## Features
- Fetches and deduplicates torrent downloads
- Compatible with private tracker RSS feeds
- Sends notifications via Discord webhook
- Configurable via XML and .env
- Works with cron or systemd timers

## Setup

```bash
git clone https://github.com/ipillyx/rss-torrent.git
cd rss-torrent
cp config.example.xml config.xml
cp .env.example .env
./rss-torrent.sh --test
```
