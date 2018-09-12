# CallMacTouchSpace
mac开发模拟键盘按下“空格”操作

根据websocket接收到的消息“space”,模拟键盘按下“空格”，从而可以操纵第三方app(如音乐软件)暂停播放。

工程包含mac端app 和 通过node-js搭建的本地websocket服务。

```
//模拟键盘按下“空格”
- (void)sendSpaceCommand
{
    CGEventRef eventDown, eventUp;
    eventDown = CGEventCreateKeyboardEvent(nil, kVK_Space, YES);
    eventUp = CGEventCreateKeyboardEvent(nil, kVK_Space, NO);
    CGEventPost(kCGHIDEventTap, eventDown);
    sleep(0.0001);
    CGEventPost(kCGHIDEventTap, eventUp);
    CFRelease(eventUp);
    CFRelease(eventDown);
}
```
