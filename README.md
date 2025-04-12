# MacWindowMonitor

Mac OS 窗口活动监控工具，用于记录和显示应用程序窗口的使用情况。

## 主要功能

### 1. 窗口活动监控
- 实时监控窗口的创建和关闭
- 记录窗口的激活和失活状态
- 自动计算窗口使用时长
- 支持多窗口同时监控

### 2. 活动记录格式
每个活动记录包含以下信息：
```json
{
    "id": 2114,
    "timestamp": "2025-04-12T16:38:40.047000+00:00",
    "duration": 8.768,
    "data": {
        "app": "Xcode",
        "title": "xcode",
        "url": null
    }
}
```

### 3. 时间记录
- 开始时间：窗口创建或激活时的时间戳
- 持续时间：窗口从激活到失活的时间长度
- 时间格式：
  - 存储格式：ISO 8601 (yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ)
  - 显示格式：本地时间 (yyyy-MM-dd HH:mm:ss)
  - 持续时间格式：HH:mm:ss.SSS

### 4. 监控事件
- 应用启动：记录新窗口的创建
- 应用退出：记录窗口的关闭和总使用时间
- 窗口激活：记录窗口进入前台的时间
- 窗口失活：记录窗口进入后台的时间

### 5. 数据展示
- 按时间倒序显示所有活动记录
- 显示应用名称和窗口标题
- 显示精确的时间戳
- 显示毫秒级的持续时间

### 6.  项目演示：
![目前demo截图](https://github.com/LiuShuoyu/MacWindowMonitor/blob/1.0.0/WindowMonitorDemo_XcodeProject/pic/demo.png?raw=true)




