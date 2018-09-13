//
//  MasterViewController.m
//  MacApp
//
//  Created by wangpo on 2018/9/11.
//  Copyright © 2018年 wangpo. All rights reserved.
//

#import "MasterViewController.h"
#import <Carbon/Carbon.h>
#import "SRWebSocket.h"

@interface MasterViewController ()<SRWebSocketDelegate>
{
    SRWebSocket         *_webSocket;
    NSTimer             *_heartbeatTimer;//心跳包
    NSInteger           _reConnectCount;//重连次数
    NSInteger           _commondCount;//收到信令次数
}

@property (strong, nonatomic) NSStatusItem *statusItem;//状态条⭐️，手动控制
@property (strong, nonatomic) NSTextField *textField;//socket地址
@property (strong, nonatomic) NSButton *connectBtn;//连接按钮
@property (strong, nonatomic) NSTextField *state;//状态信息

@end
 
@implementation MasterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    //状态栏⭐️
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [_statusItem setImage:[NSImage imageNamed:@"welcome.png"]];
    [_statusItem setHighlightMode:YES];
    [_statusItem setAction:@selector(sendSpaceCommand)];
    [_statusItem setTarget:self];
    
    _textField = [[NSTextField alloc] initWithFrame:CGRectMake(20, 220, 300, 30)];
    _textField.textColor = [NSColor redColor];
    _textField.stringValue = @"ws://10.90.90.50:4649";
    [self.view addSubview:_textField];
    
    _connectBtn = [NSButton buttonWithTitle:@"" target:self action: @selector(buttonAction:)];
    _connectBtn.title = @"Connect";
    _connectBtn.frame = CGRectMake(330, 220, 120, 30);
    [self.view addSubview:_connectBtn];
    
    _state = [[NSTextField alloc] initWithFrame:CGRectMake(20, 170, 300, 30)];
    _state.enabled = NO;
    _state.stringValue = @"断开连接";
    [self.view addSubview:_state];
    
}

- (void)buttonAction:(NSButton *)sender
{
    if ([sender.title isEqualToString:@"Connect"]) {
        sender.title = @"Disconnect";
        [self connectSocket];
    }else{
        sender.title = @"Connect";
        [self disConnectSocket];
    }
}

//核心方法：发送空格指令给电脑
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

//连接socket
- (void)connectSocket
{
    //如果socket不close,直接覆盖，会导致同时出现两个长链接的情况
    if (_webSocket) {
        [_webSocket close];
        _webSocket = nil;
    }
    NSString *serverUrl = _textField.stringValue;
    if ([serverUrl length] == 0) {
        _state.stringValue = @"地址不合法";
        return;
    }
     _state.stringValue = @"连接中";
    _webSocket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:serverUrl] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0f]];
    _webSocket.delegate = self;
    [_webSocket open];
    _reConnectCount++;
    
}

//重连
- (void)reConnectSocket
{
    //每次重连尝试更换socket地址
    [self stopHeartbeatTimer];
    _webSocket.delegate = nil;
    [_webSocket close];
    
    if (_reConnectCount == 5) {
        return;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC * _reConnectCount)), dispatch_get_main_queue(), ^{
        [self connectSocket];
    });
    
}

//断开
- (void)disConnectSocket
{
    _reConnectCount = 0;
    [self stopHeartbeatTimer];
    
    _webSocket.delegate = nil;
    [_webSocket close];
    _webSocket = nil;
    _state.stringValue = @"断开连接";
    _commondCount = 0;
}

#pragma mark - 心跳
- (void)startHeartbeatTimer
{
    if (!_heartbeatTimer){
        _heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(timerFired) userInfo:nil repeats:YES];
        [_heartbeatTimer setFireDate:[NSDate distantPast]];
    }
}

- (void)stopHeartbeatTimer
{
    if (_heartbeatTimer != nil){
        [_heartbeatTimer invalidate];
        _heartbeatTimer = nil;
    }
}

- (void)timerFired
{
    [self sendHeartBeatPack];
}

//发送心跳包
- (void)sendHeartBeatPack
{
    if (_webSocket && _webSocket.readyState == SR_OPEN) {
        [_webSocket sendPing:[NSData data]];
    }else{
        [self reConnectSocket];
    }
}

- (void)sendMessage:(NSString *)message
{
    [_webSocket send:message];
}

#pragma mark - SRWebSocketDelegate
- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    _state.stringValue = @"已连接";
    [self startHeartbeatTimer];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    [self reConnectSocket];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    NSString *command = (NSString *)message;
    if ([command isEqualToString:@"space"]) {
        _state.stringValue = [NSString stringWithFormat:@"收到space信令:%ld次",++_commondCount];
        [self sendSpaceCommand];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    [self reConnectSocket];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload
{
    //如果两个ping-pong的时间(2*30s)未收到心跳包，则认为socket已断。
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reConnectSocket) object:nil];
    [self performSelector:@selector(reConnectSocket) withObject:nil afterDelay:2*30];
}

/**
 *  消息正文 sting->jsonObject
 *
 *  @param msgData 字符串
 *
 *  @return json
 */
- (NSMutableDictionary *)getMsgContent:(NSString *)msgData
{
    NSError *JSONError = nil;
    NSData *data = [msgData dataUsingEncoding:NSUTF8StringEncoding];
    id jsonData = [NSJSONSerialization JSONObjectWithData:data
                                                  options:NSJSONReadingMutableContainers
                                                    error:&JSONError];
    return jsonData;
    
}

- (SRReadyState)getSocketState {
    return _webSocket.readyState;
}

@end
