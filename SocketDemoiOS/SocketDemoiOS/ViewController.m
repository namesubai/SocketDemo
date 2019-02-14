//
//  ViewController.m
//  SocketDemoiOS
//
//  Created by Shuqy on 2019/2/13.
//  Copyright © 2019 Shuqy. All rights reserved.
//

#import "ViewController.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
@interface ViewController (){
    NSInteger _protocolIndex;//0:TCP,1:UDP
    int _tcp_clientSockfd,_udp_clientSockfd;//客户端端套接字描述符
    NSString *_loc_ipAdr,*_loc_port,*_des_ipAdress,*_des_port;

}
@property (weak, nonatomic) IBOutlet UITextField *sendTF;
@property (weak, nonatomic) IBOutlet UITextView *recvTextView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentControl;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _loc_ipAdr = [self getIPAddress];
    _loc_port = @"10001";
    
    _des_ipAdress = @"127.0.0.1";
    _des_port = @"10000";
    [self chose:self.segmentControl];
    
    [NSThread detachNewThreadSelector:@selector(creatTCPSocket) toTarget:self withObject:nil];
    [NSThread detachNewThreadSelector:@selector(creatUDPSocket) toTarget:self withObject:nil];

    // Do any additional setup after loading the view, typically from a nib.
}

#pragma mark - 创建Socket
- (void)creatTCPSocket{
    
    _tcp_clientSockfd  = socket(AF_INET, SOCK_STREAM, 0);
    if (_tcp_clientSockfd > 0 ) {
        NSLog(@"TCP socket创建成功");
        [self connect];
        
    }else {
        NSLog(@"TCP socket创建失败");
        
    }
}

- (void)creatUDPSocket{
    
    _udp_clientSockfd  = socket(AF_INET, SOCK_DGRAM, 0);
    if (_udp_clientSockfd > 0 ) {
        NSLog(@"UDP socket创建成功");
        
        [self UDPRecv];

        
    }else {
        NSLog(@"UDP socket创建失败");
        
    }
}

#pragma mark - 连接服务器

- (void)connect {
    //获取服务器地址
    struct sockaddr_in des_addr;
    //清空指向的内存中的存储内容，因为分配的内存是随机的
    memset(&des_addr, 0, sizeof(des_addr));
    //设置协议族
    des_addr.sin_family = AF_INET;
    //设置端口
    des_addr.sin_port = htons(_des_port.intValue);
    //设置IP地址
    des_addr.sin_addr.s_addr = inet_addr(_des_ipAdress.UTF8String);
    //连接
    
    int errCode = connect(_tcp_clientSockfd, (struct sockaddr *)&des_addr, sizeof(des_addr));
    
    if (errCode == 0) {
        NSLog(@"socket连接成功");
        [self TCPRecv];
        
    }else {
        NSLog(@"socekt连接失败");
        
    }
    
}

#pragma mark - TCP接收
- (void)TCPRecv {
    char buf[1024];
    do {
        // 接收数据
        ssize_t recvLen = recv(_tcp_clientSockfd, buf, sizeof(buf), 0);
        
        if (recvLen > 0) {
            NSString *recvStr = [NSString stringWithFormat:@"[TCP消息][来自服务端%@:%@]：%@",_des_ipAdress,_des_port, [NSString stringWithUTF8String:buf]];
            NSLog(@"%@",recvStr);
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_recvTextView.text = recvStr;
            });
        }
        
    } while (strcmp(buf, "exit") != 0);
}

#pragma mark - UDP接收

- (void)UDPRecv {
    // 本地地址
    struct sockaddr_in loc_addr;
    bzero(&loc_addr, sizeof(loc_addr));
    loc_addr.sin_port        = htons(_loc_port.intValue);
    loc_addr.sin_addr.s_addr = inet_addr(_loc_ipAdr.UTF8String);
    // 绑定
    int err = bind(_udp_clientSockfd, (const struct sockaddr *)&loc_addr, sizeof(loc_addr));
    
    if (err != 0) {
        NSLog(@"socket 绑定失败");
        
    } else {
        
        NSLog(@"socket 绑定成功");
        // 目标地址
        struct sockaddr_in des_addr;
        bzero(&des_addr, sizeof(des_addr));
        des_addr.sin_family      = AF_INET;
        des_addr.sin_port        = htons(_des_port.intValue);
        des_addr.sin_addr.s_addr = inet_addr(_des_ipAdress.UTF8String);
        
        char buf[256];
        bzero(buf, sizeof(buf));
        
        while(1) {
            
            // 接收数据
            socklen_t des_addr_len = sizeof(des_addr);
            ssize_t recvLen = recvfrom(_udp_clientSockfd, buf, sizeof(buf), 0, (struct sockaddr*)&des_addr, &des_addr_len);
            
            if (recvLen > 0) {
                NSString *recvStr = [NSString stringWithFormat:@"[UDP消息][来自服务端%@:%@]：%@",_des_ipAdress,_des_port, [NSString stringWithUTF8String:buf]];
                NSLog(@"%@",recvStr);
                dispatch_async(dispatch_get_main_queue(), ^{
                    self->_recvTextView.text = recvStr;
                });
            }
        }
    }
    
}



- (IBAction)send:(id)sender {
    
    if (!self.sendTF.text.length) {
        return;
    }
    
    ssize_t sendLen = 0;
    if (_protocolIndex == 0) {
        
        // 发送数据
        sendLen = send(_tcp_clientSockfd, _sendTF.text.UTF8String, strlen(_sendTF.text.UTF8String), 0);
        
    }
    
    if (_protocolIndex == 1) {
        
        // 发送数据
        // 目标地址
        struct sockaddr_in des_addr;
        bzero(&des_addr, sizeof(des_addr));
        des_addr.sin_family      = AF_INET;
        des_addr.sin_port        = htons(_des_port.intValue);
        des_addr.sin_addr.s_addr = inet_addr(_des_ipAdress.UTF8String);
        
        // 发送数据
        sendLen = sendto(_udp_clientSockfd, _sendTF.text.UTF8String, strlen(_sendTF.text.UTF8String), 0,
                         (struct sockaddr *)&des_addr, sizeof(des_addr));
        
    }
    
    if (sendLen > 0) {
        NSLog(@"发送成功");
    }else{
        NSLog(@"发送失败");
    }
    
    
}

- (IBAction)chose:(UISegmentedControl *)sender {
    
    _protocolIndex = sender.selectedSegmentIndex;
    
    if (sender.selectedSegmentIndex == 0) {
        NSLog(@"选择TCP");
   
    }
    if (sender.selectedSegmentIndex == 1) {
        NSLog(@"选择UDP");
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



@end
