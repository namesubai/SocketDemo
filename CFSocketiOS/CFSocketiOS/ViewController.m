//
//  ViewController.m
//  CFSocketiOS
//
//  Created by Shuqy on 2019/2/15.
//  Copyright © 2019 Shuqy. All rights reserved.
//

#import "ViewController.h"
#include <sys/socket.h>
#include <netinet/in.h>
#import <arpa/inet.h>
#import <ifaddrs.h>

@interface ViewController ()
{
    NSString *_loc_ipAdr,*_loc_port,*_des_ipAdress,*_des_port;
    CFSocketRef _socketRef;
}

@property (weak, nonatomic) IBOutlet UITextView *recvTextView;
@property (weak, nonatomic) IBOutlet UITextField *sendTF;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _loc_ipAdr = [self getIPAddress];
    _loc_port = @"10001";
    
    _des_ipAdress = @"127.0.0.1";
    _des_port = @"10000";
    
     [NSThread detachNewThreadSelector:@selector(creatSocket) toTarget:self withObject:nil];
    
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)creatSocket {
    
    CFSocketContext sockContext = {0,(__bridge void *)(self),NULL,NULL,NULL};
    _socketRef = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketReadCallBack,ServerConnectCallBack, &sockContext);
    if (_socketRef != NULL) {
        NSLog(@"socket 创建成功");
        [self connect];
    }else {
        NSLog(@"socket 创建失败");

    }
    
    
}

- (void)connect {
    struct sockaddr_in addr;
    //清空指向的内存中的存储内容，因为分配的内存是随机的
    memset(&addr, 0, sizeof(addr));
    //设置协议族
    addr.sin_family = AF_INET;
    //设置端口
    addr.sin_port = htons(_des_port.integerValue);
    //设置IP地址
    addr.sin_addr.s_addr = inet_addr(_des_ipAdress.UTF8String);
    CFDataRef dataRef = CFDataCreate(kCFAllocatorDefault,(UInt8 *)&addr, sizeof(addr));
    
    CFSocketError sockError = CFSocketConnectToAddress(_socketRef,dataRef,20);
    
    if (sockError == kCFSocketSuccess) {
        NSLog(@"socket 连接成功");
    }else if(sockError == kCFSocketError) {
        NSLog(@"socket 连接失败");

    }else if(sockError == kCFSocketTimeout) {
        NSLog(@"socket 连接超时");
        
    }
    
    // 加入循环中
    // 获取当前线程的RunLoop
    CFRunLoopRef runLoopRef = CFRunLoopGetCurrent();
    // 把Socket包装成CFRunLoopSource，最后一个参数是指有多个runloopsource通过同一个runloop时候顺序，如果只有一个source通常为0
    CFRunLoopSourceRef sourceRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socketRef, 0);
    
    // 加入运行循环,第三个参数表示
    CFRunLoopAddSource(runLoopRef, //运行循环管
                       sourceRef, // 增加的运行循环源, 它会被retain一次
                       kCFRunLoopCommonModes //用什么模式把source加入到run loop里面,使用kCFRunLoopCommonModes可以监视所有通常模式添加source
                       );
    CFRunLoopRun();
    CFRelease(sourceRef);
    
}


void ServerConnectCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void * data, void *info) {
    ViewController *vc = (__bridge ViewController *)(info);
    if (data != NULL) {
        CFRelease(socket);
    }else {
        [vc performSelectorInBackground:@selector(recvData) withObject:nil];
    }
}

- (IBAction)send:(id)sender {
    if (self.sendTF.text.length) {
        NSString *sendMsg = self.sendTF.text;
        const char* data = [sendMsg UTF8String];
        ssize_t sendLen = send(CFSocketGetNative(_socketRef), data, strlen(data) + 1, 0);
        
        if (sendLen > 0) {
            NSLog(@"发送成功");
        }else{
            NSLog(@"发送失败");
        }
    }
}

- (void)recvData {
    char buffer[512];
    long readData = recv(CFSocketGetNative(_socketRef), buffer, sizeof(buffer), 0);
    //接收到的数据
    NSString *content = [[NSString alloc] initWithBytes:buffer length:readData encoding:NSUTF8StringEncoding];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recvTextView.text = [NSString stringWithFormat:@"收到消息：%@",content];
    });
    
//    while((readData = recv(CFSocketGetNative(_socketRef), buffer, sizeof(buffer), 0))) {
//
//
//
//    }
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

@end
