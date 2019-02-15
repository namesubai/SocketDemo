//
//  ViewController.m
//  CFSocketMac
//
//  Created by Shuqy on 2019/2/15.
//  Copyright © 2019 Shuqy. All rights reserved.
//

#import "ViewController.h"
#include <sys/socket.h>
#include <netinet/in.h>
#import <arpa/inet.h>
#import <ifaddrs.h>


@interface ViewController (){
    CFSocketRef _socketRef;
    NSString *_loc_ipAdr,*_loc_port,*_des_ipAdress,*_des_port;
}
@property (weak) IBOutlet NSTextField *sendTF;
@property (unsafe_unretained) IBOutlet NSTextView *recvTextView;

@end

@implementation ViewController
static ViewController *selfClass =nil;
CFWriteStreamRef _writeStreamRef;
CFReadStreamRef _readStreamRef;

- (void)viewDidLoad {
    [super viewDidLoad];
    selfClass = self;
    _loc_ipAdr = @"127.0.0.1";
    _loc_port = @"10000";
    
    _des_ipAdress = [self getIPAddress];
    _des_port = @"10001";
    [NSThread detachNewThreadSelector:@selector(creatSocket) toTarget:self withObject:nil];

    // Do any additional setup after loading the view.
}

- (void)creatSocket {
    
    CFSocketContext sockContext = {0,(__bridge void *)(self),NULL,NULL,NULL};
    _socketRef = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack,SocketAcceptCallBack, &sockContext);
    if (_socketRef != NULL) {
        NSLog(@"socket 创建成功");
        [self bind];
    }else {
        NSLog(@"socket 创建失败");
        
    }
    //允许重用本地地址和端口
    BOOL reused = YES;
    setsockopt(CFSocketGetNative(_socketRef), SOL_SOCKET, SO_REUSEADDR, (const void *)&reused, sizeof(reused));
    
}

- (void)bind {
    struct sockaddr_in addr;
    //清空指向的内存中的存储内容，因为分配的内存是随机的
    memset(&addr, 0, sizeof(addr));
    //设置协议族
    addr.sin_family = AF_INET;
    //设置端口
    addr.sin_port = htons(_loc_port.intValue);
    //设置IP地址
    addr.sin_addr.s_addr = inet_addr(_loc_ipAdr.UTF8String);
    CFDataRef dataRef = CFDataCreate(kCFAllocatorDefault,(UInt8 *)&addr, sizeof(addr));
    
    //将CFSocket绑定到指定IP地址
    CFSocketError sockError = CFSocketSetAddress(_socketRef, dataRef);
    
    if (sockError == kCFSocketSuccess) {
        NSLog(@"socket 绑定成功");
    }else if(sockError == kCFSocketError) {
        NSLog(@"socket 绑定失败");
        
    }else if(sockError == kCFSocketTimeout) {
        NSLog(@"socket 绑定超时");
        
    }
    
    //获取当前线程的CFRunLoop
    CFRunLoopRef cfRunLoop = CFRunLoopGetCurrent();
    //将_socket包装成CFRunLoopSource
    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socketRef, 0);
    //为CFRunLoop对象添加source
    CFRunLoopAddSource(cfRunLoop, source, kCFRunLoopCommonModes);
    //运行当前线程的CFRunLoop
    CFRunLoopRun();
    CFRelease(source);
    
}



- (IBAction)sendMsg:(id)sender {
    if (self.sendTF.stringValue.length) {
        NSString *sendMsg = self.sendTF.stringValue;
        const char* data = [sendMsg UTF8String];
        CFIndex sendLen = CFWriteStreamWrite(_writeStreamRef, data, strlen(data) + 1);
        if (sendLen > 0) {
            NSLog(@"发送成功");
        }else{
            NSLog(@"发送失败");
        }
    }
    
}
#pragma mark - 获取本地 IP 地址

- (NSString *)getIPAddress {
    
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    
    if (success == 0) {
        
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        
        while (temp_addr != NULL) {
            
            if (temp_addr->ifa_addr->sa_family == AF_INET) {
                
                // Check if interface is en0 which is the wifi connection on the iPhone
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    // Free memory
    freeifaddrs(interfaces);
    return address;
}
void SocketAcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void * data, void *info) {
    //如果有客户端Socket连接进来
    if (kCFSocketAcceptCallBack == type) {
        
        //获取本地Socket的Handle
        CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
        //创建一组可读/写的CFStream
        _readStreamRef  = NULL;
        _writeStreamRef = NULL;
        //创建一个和Socket对象相关联的读取数据流
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, //内存分配器
                                     nativeSocketHandle, //准备使用输入输出流的socket
                                     &_readStreamRef, //输入流
                                     &_writeStreamRef);//输出流
        
        if (_readStreamRef && _writeStreamRef) {
            
            //打开输入流和输出流
            CFReadStreamOpen(_readStreamRef);
            CFWriteStreamOpen(_writeStreamRef);
        
            
            CFStreamClientContext context = {0,NULL,NULL,NULL};
            
            /**
             指定客户端的数据流，当特定事件发生的时候，接受回调
             Boolean CFReadStreamSetClient ( CFReadStreamRef stream, 需要指定的数据流
             CFOptionFlags streamEvents, 具体的事件，如果为NULL，当前客户端数据流就会被移除
             CFReadStreamClientCallBack clientCB, 事件发生回调函数，如果为NULL，同上
             CFStreamClientContext *clientContext 一个为客户端数据流保存上下文信息的结构体，为NULL同上
             );
             返回值为TRUE就是数据流支持异步通知，FALSE就是不支持
             */
            if (!CFReadStreamSetClient(_readStreamRef,
                                       kCFStreamEventHasBytesAvailable,
                                       readStream,
                                       &context)) {
                exit(1);
            }
            
            // ----将数据流加入循环
            CFReadStreamScheduleWithRunLoop(_readStreamRef,
                                            CFRunLoopGetCurrent(),
                                            kCFRunLoopCommonModes);
            
        }else {
            // 如果失败就销毁已经连接的Socket
            close(nativeSocketHandle);
        }
    }
}

void readStream(CFReadStreamRef readStream,
                CFStreamEventType evenType,
                void *clientCallBackInfo)
{
    UInt8 buff[2048];
        
    // 从可读的数据流中读取数据，返回值是多少字节读到的，如果为0就是已经全部结束完毕，如果是-1则是数据流没有打开或者其他错误发生
    CFIndex hasRead = CFReadStreamRead(readStream, buff, sizeof(buff));
    
    if (hasRead > 0) {
        //接收到的数据
        NSString *content = [[NSString alloc] initWithBytes:buff length:hasRead encoding:NSUTF8StringEncoding];
        dispatch_async(dispatch_get_main_queue(), ^{
            selfClass.recvTextView.string = [NSString stringWithFormat:@"收到消息：%@",content];
        });

    }
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    // Update the view, if already loaded.
}

@end
