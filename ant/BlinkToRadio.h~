#ifndef BLINKTORADIO_H
#define BLINKTORADIO_H
#include <message.h>
#include <AM.h>
enum{
     TIME_FOR_BLINK = 500,
     DEST_NODE = 3,//汇聚节点
     ANT_LIVE_TIME = 12,//前行蚂蚁生存时间
     PHERO_BETA = 2,//信息素指数（暂定）
     ENERGY_BETA = 4,//能量指数（暂定）
     INVA_ADDR = -1,
};//这个优于define指令
/*
typedef nx_struct BlinkToRadioMsg{//长度：5字节
    // nx_uint8_t classify;//nx表示struct和uint16_t是外部类型
     nx_int16_t counter;
}BlinkToRadioMsg;//消息的结构定义，节点的ID号和counter

typedef nx_struct BlinkToRadioMsg2{//长度：3字节
     nx_uint8_t counter2;
     nx_int16_t counter;
}BlinkToRadioMsg2;//第二种
*/
typedef struct {   //路由表
  am_addr_t neighbor;//邻居节点号码
  bool enabled;//表示链路是否导通
  uint16_t energy;	//邻居的剩余能量，满值是10000
  am_addr_t dest;
  uint16_t phero;
} routing_table_entry;//路由表数据项

typedef nx_struct energymessage_t {	//向周围邻居报告能量情形的结构体
  nx_uint16_t energy;//能量点数
} energymessage_t;        

typedef nx_struct { //前行蚂蚁
  nx_uint16_t dest;//目的节点
  nx_uint8_t ttl;                //生存周期，最多10个
  nx_uint8_t seqno;//序列号，有可能是防止点对点传输失败的
  nx_am_addr_t  visit[12];//记录走过的节点,包括起点，不包括终点（汇聚节点）
} forwardant_t;

typedef nx_struct { //后行蚂蚁
  //nx_uint8_t ttl;//生存周期，最多十个
  nx_uint8_t hop; //采用一位小数计算，如10表示1跳。最大250=250跳跳数，当前的
  nx_am_addr_t  visit[12];//回去的节点
  nx_uint8_t seqno; //序列号，是防止点对点传输失败的 
} backwardant_t;

typedef struct {    //数据传输队列中单个消息的详细情况
  uint8_t classify;//表明消息类型,是什么类型的数据包
  energymessage_t* e_message;//类型1
  forwardant_t* f_message;//类型2
  backwardant_t* b_message;//类型3
} control_queue_entry_t;

typedef struct {    //数据传输队列中单个消息的详细情况
  uint8_t classify;//表明消息类型,是什么类型的数据包
  message_t* message;
  void* payload;
} control_queue_receive_t;

typedef nx_struct {    //数据包格式
  nx_am_addr_t        dest;	// 目的节点
  nx_am_addr_t		origin;//源节点
  nx_uint8_t				originseqno;//数据包的seqnum
  nx_uint8_t				thl;//数据包在网络中生存的跳数，最长是10
  nx_am_addr_t		visit[10];	//记录走过的路径，只记录中继节点
} ant_data_header_t;


#endif
