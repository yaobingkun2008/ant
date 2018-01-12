#define NEW_PRINTF_SEMANTICS
#include <Timer.h>
#include "ant.h"

//#include "printf.h"


configuration antAppC
{
}
implementation
{
  components ActiveMessageC;
  components new AMSenderC(6) as SendControl;//6是发送和接收控制消息的AM标识号
  components new AMReceiverC(6) as ReceiveControl;
  components MainC,LedsC;
  components antC as App;
  components new TimerMilliC() as TimerDebug;
  components new TimerMilliC() as RetxmitTimer;
  components new TimerMilliC() as MilliTimer;
  components new TimerMilliC() as Timer1;
  components new QueueC(control_queue_entry_t*, 20) as SendQueueP;//20是队列容量
  components new QueueC(control_queue_receive_t*, 20) as ReceiveQueueP;//接收信息控制队列
  
  components RandomC;
  //components PrintfC;
  components SerialStartC;

  App.Boot -> MainC.Boot;
  App.Timer1-> Timer1;
  App.TimerDebug -> TimerDebug;
  App.RetxmitTimer -> RetxmitTimer;
  App.MilliTimer -> MilliTimer;
  App.Leds -> LedsC;
  App.PacketAcknowledgements ->SendControl.Acks;
  App.Packet->SendControl;
  App.AMPacket->SendControl;
  App.BeaconSend->SendControl;
  App.BeaconReceive-> ReceiveControl;
  App.AMControl-> ActiveMessageC;
  
  App.SendQueue->SendQueueP;
  App.ReceiveQueue -> ReceiveQueueP;
  App.Random -> RandomC;  
}

