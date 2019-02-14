//
//  ViewController.m
//  SocketDemoMac
//
//  Created by Shuqy on 2019/2/13.
//  Copyright © 2019 Shuqy. All rights reserved.
//

#import "ViewController.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
@interface ViewController ()
{
    NSInteger _protocolIndex;//0:TCP,1:UDP
    NSString *_loc_ipAdr,*_loc_port,*_des_ipAdress,*_des_port;
    int _tcp_serverSockfd,_udp_serverSockfd;//服务端套接字描述符
    int _clientSockfd;//客户端端套接字描述符
    int _errCode;//绑定时的返回值
    
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _loc_ipAdr = @"127.0.0.1";
    _loc_port = @"10000";
    
    _des_ipAdress = [self getIPAddress];
    _des_port = @"10001";
    [NSThread detachNewThreadSelector:@selector(creatTCPSocket) toTarget:self withObject:nil];
    [NSThread detachNewThreadSelector:@selector(creatUDPSocket) toTarget:self withObject:nil];
    // Do any additional setup after loading the view.
}

#pragma mark - 创建Socket
- (void)creatTCPSocket{
    
   _tcp_serverSockfd  = socket(AF_INET, SOCK_STREAM, 0);
    if (_tcp_serverSockfd > 0 ) {
        NSLog(@"TCP socket创建成功");
        [self TCPBind];
    }else {
        NSLog(@"TCP socket创建失败");
        
    }
}

- (void)creatUDPSocket{
    _udp_serverSockfd  = socket(AF_INET, SOCK_DGRAM, 0);
    if (_udp_serverSockfd > 0 ) {
        NSLog(@"UDP socket创建成功");
        [self UDPBind];
    }else {
        NSLog(@"UDP socket创建失败");
        
    }
}


#pragma mark - 绑定IP地址和端口号

- (void)TCPBind {
    //获取本地地址
    struct sockaddr_in loc_addr;
    //清空指向的内存中的存储内容，因为分配的内存是随机的
    memset(&loc_addr, 0, sizeof(loc_addr));
//    loc_addr.sin_len = sizeof(struct sockaddr_in);
    //设置协议族
    loc_addr.sin_family = AF_INET;
    //设置端口
    loc_addr.sin_port = htons(_loc_port.intValue);
    //设置IP地址
    loc_addr.sin_addr.s_addr = inet_addr(_loc_ipAdr.UTF8String);
    //绑定
    _errCode = bind(_tcp_serverSockfd, (const struct sockaddr *)&loc_addr,sizeof(loc_addr) );
    if (_errCode == 0) {
        NSLog(@"TCP socket绑定成功");
        [self listen];
        
    }else {
        NSLog(@"TCP socekt绑定失败");
        
    }
    
    
  
    
}
- (void)UDPBind {
    //获取本地地址
    struct sockaddr_in loc_addr;
    //清空指向的内存中的存储内容，因为分配的内存是随机的
    memset(&loc_addr, 0, sizeof(loc_addr));
    //    loc_addr.sin_len = sizeof(struct sockaddr_in);
    //设置协议族
    loc_addr.sin_family = AF_INET;
    //设置端口
    loc_addr.sin_port = htons(_loc_port.intValue);
    //设置IP地址
    loc_addr.sin_addr.s_addr = inet_addr(_loc_ipAdr.UTF8String);
    //绑定
    int udpCode = bind(_udp_serverSockfd, (const struct sockaddr *)&loc_addr,sizeof(loc_addr) );
    
    if (udpCode == 0) {
        NSLog(@"UDP socket绑定成功");
        [self UDPRecv];
        
    }else{
        NSLog(@"UDP socekt绑定失败");
        
    }
}
#pragma mark - 监听、阻塞等待客服端的连接请求、接收消息

- (void)listen {
    _errCode = listen(_tcp_serverSockfd, 9);//9：最大连接个数
    
    if (_errCode == 0) {
        NSLog(@"socket监听成功");
        //使用循环，持续监听
        while (YES) {
            //连接的客户端的地址
            struct sockaddr_in client_addr;
            socklen_t cli_addr_len = sizeof(client_addr);
            //阻塞等待客服端的连接请求
            _clientSockfd = accept(_tcp_serverSockfd, (struct sockaddr *)&client_addr, &cli_addr_len);
            if (_clientSockfd != -1) {
                //连接成功
                NSLog(@"socket连接成功");

            }
            //创建一个字符串接收
            char buf[1024];
            do {
                // 返回读取的字节数
                ssize_t recvLen = recv(_clientSockfd, buf, sizeof(buf), 0);
                
                if (recvLen > 0) {
                    NSString *recvStr = [NSString stringWithFormat:@"[TCP消息][来自客户端%@:%@]：%@",_des_ipAdress,_des_port, [NSString stringWithUTF8String:buf]];
                    NSLog(@"%@",recvStr);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self->_recTextView.string = recvStr;
                    });
                    
                }
                
            } while (strcmp(buf, "exit") != 0);
        }
        
        
    }else {
        NSLog(@"socekt监听失败");
        
    }
}

#pragma mark - UDP接收
- (void)UDPRecv{
    // 目标地址
    struct sockaddr_in des_addr;
    bzero(&des_addr, sizeof(des_addr));
    des_addr.sin_family      = AF_INET;
    des_addr.sin_port        = htons(_des_port.intValue);
    des_addr.sin_addr.s_addr = inet_addr(_des_ipAdress.UTF8String);
    
    char buf[1024];
    //清空指向的内存中的存储内容
    bzero(buf, sizeof(buf));
    
    while(1) {
        
        // 接收数据
        socklen_t des_addr_len = sizeof(des_addr);
        ssize_t recvLen = recvfrom(_udp_serverSockfd, buf, sizeof(buf), 0, (struct sockaddr*)&des_addr, &des_addr_len);
        
        if (recvLen > 0) {
            NSString *recvStr = [NSString stringWithFormat:@"[UDP消息][来自客户端%@:%@]：%@",_des_ipAdress,_des_port, [NSString stringWithUTF8String:buf]];
            NSLog(@"%@",recvStr);

            dispatch_async(dispatch_get_main_queue(), ^{
                self->_recTextView.string = recvStr;
            });
        }
    }
}



#pragma mark - 发送
- (IBAction)sendMsg:(id)sender {
    if (!self.textInput.stringValue.length) {
        return;
    }
    
    NSString *sendMsg = self.textInput.stringValue;
    
    ssize_t sendLen = 0;
    if (_protocolIndex == 0) {
        
        // 发送数据
        sendLen = send(_clientSockfd, sendMsg.UTF8String, strlen(sendMsg.UTF8String), 0);
        
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
        sendLen = sendto(_udp_serverSockfd, sendMsg.UTF8String, strlen(sendMsg.UTF8String), 0,
                         (struct sockaddr *)&des_addr, sizeof(des_addr));
        
    }
    
    if (sendLen > 0) {
        NSLog(@"发送成功");
    }else{
        NSLog(@"发送失败");
    }
}
#pragma mark - 选择协议
- (IBAction)choseProtocol:(NSComboBox *)sender {
    if ([sender.stringValue isEqualToString:@"TCP"]) {
        NSLog(@"选择TCP");
        _protocolIndex = 0;

    }
    if ([sender.stringValue isEqualToString:@"UDP"]) {
        NSLog(@"选择UDP");
        _protocolIndex = 1;

    }

    
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
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
