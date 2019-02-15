//
//  ViewController.m
//  AsyncSocketiOS
//
//  Created by Shuqy on 2019/2/15.
//  Copyright © 2019 Shuqy. All rights reserved.
//

#import "ViewController.h"
#import "GCDAsyncSocket.h"
#include <netinet/in.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
@interface ViewController ()<GCDAsyncSocketDelegate>
{
    GCDAsyncSocket *_clientSocket;
    NSString *_loc_ipAdr,*_loc_port,*_des_ipAdress,*_des_port;

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
    
    //创建socket
    _clientSocket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    //连接服务器
    NSError *error;
    [_clientSocket connectToHost:_des_ipAdress onPort:_des_port.integerValue error:&error];
    if (error) {
        NSLog(@"socket 连接失败");
    }
    
    
    // Do any additional setup after loading the view, typically from a nib.
}


#pragma mark - GCDAsyncSocketDelegate

// 连接成功
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"socket 连接成功");
    // 读取数据，必须添加，相当于主动添加一个读取请求，不然不会执行读取信息回调方法
    [_clientSocket readDataWithTimeout:-1 tag:0];
   
}

// 已经断开链接
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    
    NSLog(@"socket 断开连接");
}

//读取到数据
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    
    // 注意：要想长连接，必须还要在 DidReceiveData 的 delegate 中再写一次 [_udpSocket receiveOnce:&error]
    // 读取数据，读取完信息后，重新向队列中添加一个读取请求，不然当收到信息后不会执行读取回调方法。
    [_clientSocket readDataWithTimeout:-1 tag:0];
    
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    self.recvTextView.text = [NSString stringWithFormat:@"收到消息：%@",str];
}


//发送消息
- (IBAction)send:(id)sender {
    
   [_clientSocket writeData:[self.sendTF.text dataUsingEncoding:NSUTF8StringEncoding] withTimeout:30 tag:0];
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
