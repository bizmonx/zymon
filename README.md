# The Frontend

**W I P: <started>**

## Features
- [x] communicate with xymon (xymondboard)
- [ ] display tests for a group of hosts
  - [x] build (sorted) column list from tests of all hosts in scope
  - [x] get all hosts/items in scope (page, group, ..)
  - [x] consolidated color on color indicator (heart top right)
  - [ ] fix first column, scroll horizontally
  - [ ] fix header row, scroll vertically
- [ ] individual test page
  - [x] update color indicator for test view
  - [x] display title, parse content

- [ ] drop a test
- [ ] display graphs
- [ ] ...



## Introduction
The part that needs the most work, and not only cometically. The html pages are generated at intervals and a hardcoded refresh on the page reloads itself every minute.  This will be more realtime and only what needs to be updated will be updated.

## Technologies used

- Zig (0.11)
- Zap [A blazingly fast web server](https://github.com/zigzap/zap)
- [htmx] (https://htmx.org/)

## How it works

For now, we'll use "xymondboard" calls to get to the data by communicating with xymon on tcp/1984.
The history is stored in files on disk, as well as the rrd graphs.  Before bringing the charts to the frontend,
we'll store that in a db first.  Not sure yet what to use to render the charts.  Grafana is ok, but not if
we want this to be able to run on a raspberry pi zero.

## sneak peek
![first look](https://github.com/bizmonx/zymon/blob/main/img/firstlook.png)
