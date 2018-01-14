#include <Timer.h>
#include "ant.h"
//#include "printf.h"

//接口是一组函数的集合，包括命令和事件
module antC @safe()
{
   uses interface Timer<TMilli> as Timer1;
  uses interface Timer<TMilli> as TimerDebug;//用来显示队列中的情况
  uses interface Timer<TMilli> as RetxmitTimer;//延迟机制计时器接口
  uses interface Timer<TMilli> as MilliTimer;//用来周期性报告电量的计时器
  uses interface Leds;//led灯接口
  uses interface Boot;//启动接口
  uses interface Packet;
  uses interface AMPacket;//用于访问message_t类型的数据变量
  uses interface AMSend as BeaconSend;//用于发送控制报文
  uses interface Receive as BeaconReceive;//
  uses interface SplitControl as AMControl;//用于初始化
  uses interface Queue<control_queue_entry_t*> as SendQueue;//发送队列
  uses interface Queue<control_queue_receive_t*> as ReceiveQueue;//接收队列
  uses interface Random;
  uses interface PacketAcknowledgements;
}
implementation
{
  routing_table_entry routing_table[15];//路由表
  uint8_t tableactive;//路由表项
  uint16_t battery;//电量
  bool isrunning;
  bool busy = FALSE;
  message_t pkt;
  message_t pkt2;
  message_t pkt3;
  uint8_t hellonum;
  uint8_t chenggong = -1;
  uint8_t forward_num = 0;//发送前行蚂蚁数量
  uint8_t backward_num = 0;//发送后行蚂蚁数量
  uint8_t post_fail ;
  uint8_t flag;
  uint8_t receiveantnum;
  uint8_t sendnum;
  uint8_t testnum;
  uint8_t battery_level;
  //bool ack_pending;
  bool receiving;
  bool is_destable()//检测本节点是否与汇聚节点相邻,这里返回值定义是否正确？
  {
  	uint8_t i;
  	for(i = 0;i<tableactive;i++)
  	{
  		if(routing_table[i].neighbor == DEST_NODE&&routing_table[i].enabled == TRUE)
  		{
  			return 1;
  		}
  	}
  	return 0;
  }


  event void Boot.booted()//在这里初始化一切模块
  {
      call AMControl.start();//先启动一些模块
  }

  event void AMControl.startDone(error_t err)//初始化模块
  {
      if(err==SUCCESS){
               post_fail = 0;//
               battery_level = 10;
      	  tableactive = 0;//路由表项设置为0个
      	  battery = 10000;//满电是10000
      	  isrunning = TRUE;//表示是否位于休眠状态
      	  hellonum = 0;
          	  forward_num = -1;
               receiveantnum = -1;
                sendnum = -1;
      	  //其他要初始化的。。。。。。
      	  testnum = -1;
      	  receiving = FALSE;

              //call TimerDebug.startPeriodic(250);
              if(TOS_NODE_ID!=DEST_NODE)
              {
              	call Timer1.startOneShot(4000);
              }
              call MilliTimer.startOneShot(100);//每隔一段时间，检测一次电池电量并广播，这里暂定是每4s广播一次...
      }
      else{
	  	  call AMControl.start();//如果不成功，重新启动直到启动成功为止
      }
  }//自带了error_t类型的err变量，如果没有成功开启，就返回的err为SUCCESS
   
  event void AMControl.stopDone(error_t err){
	
  }

 

uint8_t check_battery_change()//there may be problem
{
       atomic{
	if(battery>=9000)
	{
		if(battery_level != 10)
		{
			battery_level = 10;
			return 2;
		}
		else
		{
			return 1;
		}
       	}
       	else if(battery<9000 && battery>=8000)
       	{
       		if(battery_level != 9)
       		{
       			battery_level = 9;
       			return 2;
       		}
       		else
       		{
       			return 1;
       		}
       	}
       	else if(battery<8000 && battery>=7000)
       	{
       		if(battery_level != 8)
       		{
       			battery_level = 8;
       			return 2;
       		}
       		else
       		{
       			return 1;
       		}
       	}
       	else if(battery<7000 && battery>=6000)
       	{
       		if(battery_level != 7)
       		{
       			battery_level = 7;
       			return 2;
       		}
       		else
       		{
       			return 1;
       		}
       	}
       	else if(battery<6000 && battery>=5000)
       	{
       		if(battery_level != 6)
       		{
       			battery_level = 6;
       			return 2;
       		}
       		else
       		{
       			return 1;
       		}
       	}
       	else if(battery<5000 && battery>=4000)
       	{
       		if(battery_level != 5)
       		{
       			battery_level = 5;
       			return 2;
       		}
       		else
       		{
       			return 1;
       		}
       	}
       	else if(battery<4000 && battery>=3000)
       	{
       		if(battery_level != 4)
       		{
       			if(isrunning == TRUE)
       			{
       				battery_level = 4;
       				return 2;
       			}
       			else if(isrunning == FALSE)
       			{
       				battery_level = 4;
       				isrunning = TRUE;
       				return  4;
       			}
       		}
       		else
       		{
       			return 1;
       		}
       	}

       	else if(battery<3000 && battery>=2000)
       	{
       	             if(battery_level > 3)
       		{
       			battery_level = 3;
       			return 2;
       		}
       		else if(battery_level ==2 && isrunning == FALSE)
       		{
       			battery_level = 2;
       			return 1;
       		}
       		else 
       		{
       			return 1;
       		}
       	}
       	else if(battery<2000)
       	{
       		if(battery_level >2)//can be ==3
       		{
       			battery_level = 2;
       			isrunning = FALSE;
       			return 3;
       		}
       		else
       		{
       			return 1;
       		}
       	}
       }
}



  bool findin(uint8_t ttl,uint8_t visited[12],uint8_t neighbor)
  {
    bool isin = FALSE;
    int k;
    for(k=0;k<12-ttl;k++)
    {
        if(visited[k]==neighbor)
        {
            //cout<<routing_table[k].neighbor;
            isin = TRUE;
            break;
        }
    }
    return isin;
  }
  am_addr_t find_next_hop(uint8_t ttl,uint8_t visited[ANT_LIVE_TIME],uint16_t destin)//核心函数之所在
  {
	    uint32_t bignum = 0;
	    uint8_t k;
	    uint8_t g = 0;//can be use for houxuan
	    uint8_t select[15];
	    uint8_t s_num;
	    for(k=0;k<tableactive;k++)
	    {
	      	if(routing_table[k].enabled==TRUE)//首先链路不能失效
	      	{
	        		if(routing_table[k].dest == destin)
	        		{
	          			if(findin(ttl,visited,routing_table[k].neighbor)==FALSE)
	          			{		
	            				uint32_t c = (routing_table[k].energy)*(routing_table[k].phero);
	            				if(c>bignum)
	            				{
	            					g = 1;
	            					select[0] = routing_table[k].neighbor;
	              				bignum = c;
	            				}
	            				else if(bignum == c)
	            				{
	            					g++;
	            					select[g-1] = routing_table[k].neighbor;
	            					bignum = c; 
	            				}
	          			}
	        		}
	      	}
	    }
	    if(g==0)
	    {
	    	return 99;
	    }
	    else if(g==1)
	    {
	    	return select[0];
	    }
	    else if(g>1)
	    {
	    	uint16_t r = call Random.rand16();
		uint8_t s_num = r%g;
	    	return select[s_num];
	    }
  }

  task void senddatatask(){//注意访问路由表的操作务必串行！防止这一步读到不完整的路由表项！
           //atomic{
              uint8_t k  = 0;
	if(busy==TRUE || receiving == TRUE)//如果busy等于true推迟一段时间，此次任务作废并且再重新提交任务，否则就发送
	{
		uint16_t r  = call Random.rand16();
		r = r%10;
		r = r+10;
		//dbg("Test1","busy!\n");
		call RetxmitTimer.startOneShot(r);
        		return;
	}
	else
	{
		control_queue_entry_t* pac_send = call SendQueue.head();
		energymessage_t* btrpkt = NULL;
    		forwardant_t* btrpkt2 = NULL;
    		backwardant_t* btrpkt3 = NULL;
              	uint8_t h = -1;
              	uint8_t j;
    		if(pac_send!=NULL)
    		{
	    		if(pac_send->classify==1)//发送电池信息广播包
			{
				//printf("the class is energy\n");
				btrpkt = (energymessage_t*)(call Packet.getPayload(&pkt,NULL));
				btrpkt->energy = pac_send->e_message->energy;

				/*if (call PacketAcknowledgements.requestAck(&pkt)==SUCCESS)
				{
					ack_pending = TRUE;
				}*/

	      			if(call BeaconSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(energymessage_t))==SUCCESS)
	      			{//广播

	      				flag = 1;
			   		busy = TRUE;
				}
				else//发送不成功，重发
				{
				              dbg("Test1","send failed!\n");
			    		if(post senddatatask()!=SUCCESS)
			    		{
			    			dbg("Test1","gg!\n");
			    		}
				}
				return;
			}
			else if(pac_send->classify==2)//如果是前向蚂蚁，可能是始发或者转发（不会是收到），两种情况用一样的代码就行
			{
				//dbg("Test1","%u is sending\n",pac_send->f_message->seqno);

			            	btrpkt2 = (forwardant_t*)(call Packet.getPayload(&pkt2,NULL));
			            	btrpkt2->dest = pac_send->f_message->dest;
			            	btrpkt2->ttl = (pac_send->f_message->ttl)-1;
			            	btrpkt2->seqno = pac_send->f_message->seqno;
			            	
			            	for(k=0;k<ANT_LIVE_TIME-(btrpkt2->ttl);k++)
			            	{
			            		btrpkt2->visit[k] = pac_send->f_message->visit[k];
			            	}


			            	if(is_destable()==1)//如果可以直达终点
			            	{
			            	           //  dbg("Test1","the next hop of %u is %u\n",btrpkt2->seqno,DEST_NODE);
			            		//call PacketAcknowledgements.noAck(&pkt2);
			            		/*if (call PacketAcknowledgements.requestAck(&pkt2)==SUCCESS)
					{
						ack_pending = TRUE;
					}*/
			            		if(call BeaconSend.send(DEST_NODE,&pkt2,sizeof(forwardant_t))==SUCCESS)
			            		{
			            			if(TOS_NODE_ID==0)
				            		{
				            			//dbg("Test1","send forward antaaaaa %u.%u\n",TOS_NODE_ID,btrpkt2->seqno);
				            		}
			            			flag = 2;
			            			busy = TRUE;
			            			//dbg("Test1","send %u success\n",btrpkt2->seqno);
			            			/*if(btrpkt2->ttl == ANT_LIVE_TIME-1)
			            			{
			            				call Timer1.startOneShot(800);
			            			}*/

			            		}
			            		else//发送不成功，重发
					{
						dbg("Test1","send failed!\n");		
					    	if(post senddatatask()!=SUCCESS)
					    	{
					    		dbg("Test1","gg!\n");
					    	}
					}
					return;
			            	}
			            	else//如果不能直达终点,就要先找下一跳节点
			            	{
			            		uint16_t nexthop = find_next_hop(btrpkt2->ttl,btrpkt2->visit,btrpkt2->dest);//核心函数所在！这里用一个概率路由，一定就要选几率最大的
			            		//dbg("Test1","the next hop of %u is %u\n",btrpkt2->seqno,nexthop);
			            		if(nexthop == 99)//if nexthop can not be found
			            		{
			            			dbg("Test1","%u nexthop not found!\n",btrpkt2->seqno);
			            			 call SendQueue.dequeue();
			            			 return;
			            		}
			            		else
			            		{
			            			//call PacketAcknowledgements.noAck(&pkt2);
			            			/*if (call PacketAcknowledgements.requestAck(&pkt2)==SUCCESS)
						{
							ack_pending = TRUE;
						}*/
				            		if(call BeaconSend.send(nexthop,&pkt2,sizeof(forwardant_t))==SUCCESS)
				            		{
				            			
				            			flag = 2;
				            			busy = TRUE;
				            			//dbg("Test1","send %u success\n",btrpkt2->seqno);
				            			/*if(btrpkt2->ttl == ANT_LIVE_TIME-1)//shifa
				            			{
				            				call Timer1.startOneShot(2800);
				            			}*/
				            		}
			            			else//发送不成功，重发
						{
							dbg("Test1","send failed!\n");
			                			//printf("send forward ant failed!\n");
					    		if(post senddatatask()!=SUCCESS)
					    		{
					    			dbg("Test1","gg!\n");
					    		}
						}
			                                         return;

			            		}

		             		}
	          
			}
			else if(pac_send->classify == 3)//如果是后向蚂蚁,包括转发和始发
			{
		                            uint16_t nexthop = pac_send->b_message->visit[0];//下一跳永远是第一个
		                            //dbg("Test1","backward:the next hop is %u",nexthop);
				btrpkt3 = (backwardant_t*)(call Packet.getPayload(&pkt3,NULL));
		                            btrpkt3->hop = (pac_send->b_message->hop)+1;
		                            btrpkt3->seqno = pac_send->b_message->seqno;
		                            btrpkt3->roadlength = pac_send->b_message->roadlength;
		                            for(j=1;j<1+(btrpkt3->roadlength)-(btrpkt3->hop);j++)
		                            {
		                                  h++;
		                                  btrpkt3->visit[h] = pac_send->b_message->visit[j];
		                            }
		                            if(call BeaconSend.send(nexthop,&pkt3,sizeof(backwardant_t))==SUCCESS)
		                            {//广播
		                                    flag = 3;//表示发送的是后向蚂蚁
		                                    busy = TRUE;
		                            }
		                            else//发送不成功，重发
		                            {
		                                    dbg("Test1","send failed!\n");
		                                    if(post senddatatask()!=SUCCESS)
		                                    {
		                                            dbg("Test1","gg!\n");
		                                    }
		                            }
		                            return;
			}
			else{
				dbg("Test1","wrong!\n");
			}
		}
		else
		{
			return;
		}
	}
      // }
  }

void send_battery_info(){

  	control_queue_entry_t* new_packet = (control_queue_entry_t*)malloc(sizeof(control_queue_entry_t));
	new_packet->e_message = (energymessage_t*)malloc(sizeof(energymessage_t));
	new_packet->e_message-> energy= battery_level;
	new_packet->f_message = NULL;
	new_packet->b_message = NULL;	
	new_packet->classify = 1;
	if(call SendQueue.enqueue(new_packet)==SUCCESS)//这里可能将会出现问题
	{
		if(post senddatatask()!=SUCCESS)
		{
		    	dbg("Test1","gg!\n");
		}
	}
	else
	{
		dbg("Test1","shit!");
	}
      
 }

  uint8_t findinroutingtable(am_addr_t neighbor)//当有多个汇聚节点的时候，这里就不对了
  {
  	uint8_t i;
/*
  	if(neighbor==INVALID_ADDR)//按照原版所说，这里可能有一些bug？
  	{
  		return tableactive;
  	}
*/
  	for(i = 0;i<tableactive;i++)
  	{
  		if(routing_table[i].neighbor == neighbor)
  		{
  			break;
  		}
  	}
  	return i;
  }

  task void Receivedatatask(){
        //atomic{
        	uint8_t idx;
	 int8_t k;
	 control_queue_receive_t* pac_receive = call ReceiveQueue.head();
        	if(receiving == TRUE)
        	{
        		dbg("Test1","receiving busy!\n");
        		post Receivedatatask();
        		return;
        	}
	 
  	
  	if(pac_receive->classify==1)//第一种情况，收到的是电池广播包
  	{
  		am_addr_t hellofrom;//来源的邻居节点
  		energymessage_t* a = (energymessage_t*)(pac_receive->payload);
  		hellofrom = call AMPacket.source(pac_receive->message);
		idx = findinroutingtable(hellofrom);
  		if(idx == 15)//不能加入路由表，丢弃
  		{
  			call ReceiveQueue.dequeue();
  			return;
  		}
  		else if(idx == tableactive){//没有找到，但是还有空间
  			routing_table[idx].neighbor = hellofrom;
  			routing_table[idx].enabled = TRUE;
  			routing_table[idx].energy = a->energy;
  			routing_table[idx].dest = DEST_NODE;//汇聚节点为35
  			routing_table[idx].phero = NEW_PHERO;//初始化信息素浓度
  			routing_table[idx].hop = ANT_LIVE_TIME;//跳数
  			tableactive++;
  			call ReceiveQueue.dequeue();
  			return;
  		}
  		else if(idx < tableactive){//找到了已经有的，更新之
  			routing_table[idx].energy = a->energy;
  			if(routing_table[idx].enabled == TRUE && routing_table[idx].energy == 2)//能量小于百分之20，就可认为链路已失效。
  			{
  				routing_table[idx].enabled = FALSE;
  				routing_table[idx].phero = 0;//信息素浓度设为0
  			}
  			else if(routing_table[idx].enabled == FALSE && routing_table[idx].energy > 2)//wake up from sleeping
  			{
  				routing_table[idx].enabled = TRUE;
  				routing_table[idx].phero = BACK_PHERO;//信息素数值回到一个值，这个值是什么还要考虑
  			}
  			call ReceiveQueue.dequeue();
  			return;
  		}
  	}
  	else if(pac_receive->classify==2)//收到了前向蚂蚁，有可能是转发或者最终收到
  	{

      		forwardant_t* a = (forwardant_t*)(pac_receive->payload);
      		//dbg("Test1","receive ant num is:%u\n",a->seqno);
		      if(a->ttl==0)//如果生存时间为0
		      {
		      	
		      	call ReceiveQueue.dequeue();
		      	return;
		      }
		      else
		      {
		      	uint8_t u = -1;
		      	if(TOS_NODE_ID == a->dest)//如果前行蚂蚁到达汇聚节点，应该构建后向蚂蚁
		      	{
                            		control_queue_entry_t* new_backward = NULL;
		      		testnum++;
		      		//dbg("Test1","ARRIVED AT SINK NODE! @ %u.%u\n",a->visit[0],a->seqno);
		      		new_backward = (control_queue_entry_t*)malloc(sizeof(control_queue_entry_t));
				new_backward->b_message = (backwardant_t*)malloc(sizeof(backwardant_t));
				new_backward->b_message->hop = 0;//初始定义为距离终点0跳
				new_backward->b_message->seqno = backward_num;
                            		new_backward->b_message->roadlength = ANT_LIVE_TIME-(a-> ttl);
                            		/*下面是为了查看0号节点目前生成的路径*/
                            		if(a->visit[0]==0)
                            		{
                            			//dbg("Test1","the ttl is:%u\n",a->ttl);
                            			dbg("Test1","the road of MOTE 0 is: ");
                            			for(k = 0;k<ANT_LIVE_TIME - (a->ttl);k++)
                            			{
                            				//dbg("Test1","--------");
                            				dbg("Test1"," %u",a->visit[k]);
                            			}
                            			dbg("Test1","\n");
                            		}
				for(k=ANT_LIVE_TIME-(a->ttl)-1;k>=0;k--)//这里出错了，无符号数是不能减到0以下的。
		      		{
		      		       // dbg("Test1","%u\n",k);
		      		        u++;
		        		        new_backward->b_message->visit[u] = a->visit[k];
		      		}
		      		//dbg("Test1","haha\n");
		      		new_backward->e_message = NULL;
		      		new_backward->f_message = NULL;
		      		new_backward->classify = 3;
		      		if(call SendQueue.enqueue(new_backward)==SUCCESS)//入队
				{
				       if(post senddatatask()!=SUCCESS)
				       {
				    	dbg("Test1","gg!\n");
				       }
				       call ReceiveQueue.dequeue();
		      		       return;
				}
		      		else 
		      		{
		      			dbg("Test1","shit!\n");
		      		}
		      	}
		      	else//应当转发，要加入发送队列
		      	{
		      		   control_queue_entry_t* new_forward = NULL;
		      		   //dbg("Test1","%u ARRIVED AT INTER NODE %u\n",a->seqno,TOS_NODE_ID);
		      		   new_forward = (control_queue_entry_t*)malloc(sizeof(control_queue_entry_t));
				   new_forward->f_message = (forwardant_t*)malloc(sizeof(forwardant_t));
				   new_forward->f_message->dest = a->dest;//这里默认为35号节点
				   new_forward->f_message->ttl = a->ttl;
				   new_forward->f_message->seqno = a->seqno;
				   for(k=0;k<ANT_LIVE_TIME-(a->ttl);k++)
		      		   {
		        			new_forward->f_message->visit[k] = a->visit[k];
		      		   }
		      		   new_forward->f_message->visit[ANT_LIVE_TIME-(a->ttl)] = TOS_NODE_ID;//记录
				    new_forward->e_message = NULL;
				    new_forward->b_message = NULL;
				    new_forward->classify = 2;
				    if(call SendQueue.enqueue(new_forward)==SUCCESS)//入队
				    {
				               if(post senddatatask()!=SUCCESS)
				               {
				    		dbg("Test1","gg!\n");
				               }
				               call ReceiveQueue.dequeue();
		      		               return;
				    }
				    else
				    {
				    	dbg("Test1","shit!");
				    }
		      	}
		  }
  	}
  	else if(pac_receive->classify==3)//有两种可能性，一是中转，二是最终收到，但是都要先完成信息素的变化,然后再更新信息素，区别只是要不要转发
  	{
  		am_addr_t from;
  		uint8_t k;
              backwardant_t* a = (backwardant_t*)(pac_receive->payload);
              from = call AMPacket.source(pac_receive->message);
  		//先蒸发一定比例的信息素，这又个问题，要不要考虑已经休眠的节点？
  		for(k=0;k<tableactive;k++)
  		{
  			routing_table[k].phero = routing_table[k].phero*REMAIN_RATIO/100;
  		}
  		//更新跳数和对应链路的信息素浓度，假如该节点已经休眠？
  		idx = findinroutingtable(from);//当有两个汇聚节点的时候，这里就不对了
  		//理论上来说，idx不可能存在找不到的情况，所以先不就这种情况作处理
  		//更新信息素和跳数
  		if(a->hop < routing_table[idx].hop)
  		{
  			routing_table[idx].hop = a->hop;
  		}
  		routing_table[idx].phero = routing_table[idx].phero + UPDATE_NUM/a->hop;
  		if(a->hop == a->roadlength)//到达终点
  		{
  			call ReceiveQueue.dequeue();
		      	return;
  		}
  		else//转发
  		{
  			control_queue_entry_t* new_backward = NULL;
		      	new_backward = (control_queue_entry_t*)malloc(sizeof(control_queue_entry_t));
			new_backward->b_message = (backwardant_t*)malloc(sizeof(backwardant_t));
			new_backward->b_message->hop = a->hop;//初始定义为距离终点0跳
			new_backward->b_message->seqno = a->seqno;
                     new_backward->b_message->roadlength = a->roadlength;
                     for(k = 0;k<(a->roadlength)-(a->hop);k++)
		      	{
		      		new_backward->b_message->visit[k] = a->visit[k];
		      	}
		      	new_backward->e_message = NULL;
		      	new_backward->f_message = NULL;
		      	new_backward->classify = 3;
		      	if(call SendQueue.enqueue(new_backward)==SUCCESS)//入队
			{
				if(post senddatatask()!=SUCCESS)
				{
				    	dbg("Test1","gg!\n");
				}
				call ReceiveQueue.dequeue();
		      		return;
			}
			else
			{
				dbg("Test1","shit!");
			}
  		}
  	}


       //}

  }




  event void RetxmitTimer.fired(){
	if(post senddatatask()!=SUCCESS)
	{
	              dbg("Test1","gg!\n");
              }//重新提交任务,防止繁忙
  }
  
  event void TimerDebug.fired()//打印队列长度
  {
	uint8_t i;
    /*  printf("the length of sendqueue is %u\n",call SendQueue.size());
      printf("the success send packet num is %u\n",chenggong);
      printf("the length of receivequeue is %u\n",call ReceiveQueue.size());
      printf("the tableactive is %u\n",tableactive);
      for(i=0;i<tableactive;i++)
	{
		
		printf("[neighbor=%u,enabled = %u,energy=%u,dest=%u,phero=%u]\n",routing_table[i].neighbor,routing_table[i].enabled,routing_table[i].energy,routing_table[i].dest,routing_table[i].phero);

	}*/
	//dbg("Test1","the length of sendqueue is %u @%u\n",call SendQueue.size(),TOS_NODE_ID);
	//dbg("Test1","the length of receivequeue is %u @%u\n",call ReceiveQueue.size(),TOS_NODE_ID);
	//dbg("Test1","the tableactive is %u @%u\n",tableactive,TOS_NODE_ID);
	if(TOS_NODE_ID==DEST_NODE)
	{
		//dbg("Test1","the receivenum is %u\n",testnum);
	}
	 for(i=0;i<tableactive;i++)
	{
		//dbg("Test1","[neighbor=%u,enabled = %u,energy=%u,dest=%u,phero=%u] @%u\n",routing_table[i].neighbor,routing_table[i].enabled,routing_table[i].energy,routing_table[i].dest,routing_table[i].phero,TOS_NODE_ID);
	}
  }
  
event void Timer1.fired()
{
      // atomic{
           if(receiving == FALSE)
           {
	control_queue_entry_t* new_forward = NULL;
	 if(TOS_NODE_ID!=DEST_NODE)
        	 {
        	               forward_num++;
        	            //   dbg("Test1","send forward ant %u.%u\n",TOS_NODE_ID,forward_num);
		  new_forward = (control_queue_entry_t*)malloc(sizeof(control_queue_entry_t));
		  new_forward->f_message = (forwardant_t*)malloc(sizeof(forwardant_t));
		  new_forward->f_message->dest = DEST_NODE;//这里默认为35号节点
		  new_forward->f_message->ttl = ANT_LIVE_TIME;
		  new_forward->f_message->seqno = forward_num;
		  new_forward->f_message->visit[0] = TOS_NODE_ID;//起点节点号，这里可能有疑点
		  new_forward->e_message = NULL;
		  new_forward->b_message = NULL;
		  new_forward->classify = 2;//前行蚂蚁，代号是2
		  if(call SendQueue.enqueue(new_forward)==SUCCESS)//入队
		  {
		           if(post senddatatask()!=SUCCESS)
		           {
		    	          atomic{
		    	          	    post_fail++;
		    	          }
		           }
		  }
		  else
		  {
		           dbg("Test1","shit!");
		  }
              }
        }
        //}
}

  event void BeaconSend.sendDone(message_t* msg,error_t error){//maybe need acks
         uint8_t k;
         if(flag ==3)
         {
              if(&pkt3 == msg)
              {
                    call SendQueue.dequeue();
                    battery = battery - 5;
                   if(check_battery_change()!=1)
                   {
                        send_battery_info();
                   }
                   busy = FALSE;
                   atomic{
                         uint8_t k;
                         uint8_t j = post_fail; 
                         if(post_fail!=0)
                         {
                                for(k = 1;k<=post_fail;k++)
                                {
                                       if(post senddatatask()==SUCCESS)
                                       {
                                              j--;
                                       }
                                }
                         }
                         post_fail = j;
                    }
              }
              else 
              {
                          busy = FALSE;
                          dbg("Test1","send back ant error!\n");
                          post senddatatask();
              }
         }

	  if(flag==2)
	  {
	  	if(&pkt2 == msg)
	  	{
	  		
	  		/*   if(TOS_NODE_ID==0)
			  {
				dbg("Test1","send forward ant %u\n",forward_num);
			  }*/
			/*if(TOS_NODE_ID==1 || TOS_NODE_ID ==2)
			{
				sendnum++;
				dbg("Test1","NODE %u send %u\n",TOS_NODE_ID,sendnum);
			}*/
			   call SendQueue.dequeue();//发送成功之后再出队
			   battery = battery-5;//每发送一个，电量-5
			   if(check_battery_change()!=1)
			   {
			   	send_battery_info();
			   }
			   busy = FALSE;
			  
			   //next operation should be atomic
			   atomic{
				   uint8_t k;
				   uint8_t j = post_fail;	
				   if(post_fail!=0)
				   {
				   	for(k = 1;k<=post_fail;k++)
				   	{
				   		if(post senddatatask()==SUCCESS)
				   		{
				   			j--;
				   		}
				   	}
				   }
				   post_fail = j;
			   }
			
			   if(TOS_NODE_ID!=DEST_NODE)
			   {
			   	call Timer1.startOneShot(1800);//start the next period
			   }
		   }
		   else 
		   {
		   	
		             busy = FALSE;
			dbg("Test1","send ant error!\n");
		   	post senddatatask();
		   }
	   }
	    if(flag==1)
	  {
	  	if(&pkt == msg)
	  	{
			   call SendQueue.dequeue();//发送成功之后再出队
			   battery = battery-5;//每发送一个，电量-5
			   if(check_battery_change()!=1)
			   {
			   	send_battery_info();
			   }
			   busy = FALSE;
			  
			   //next operation should be atomic
			   atomic{
				   uint8_t k;
				   uint8_t j = post_fail;	
				   if(post_fail!=0)
				   {
				   	for(k = 1;k<=post_fail;k++)
				   	{
				   		if(post senddatatask()==SUCCESS)
				   		{
				   			j--;
				   		}
				   	}
				   }
				   post_fail = j;
			   }
			if(hellonum<5)
			{
				hellonum++;//发送的数量+1
				call MilliTimer.startOneShot(250);
			}
		   }
		   else 
		   {
		   	
		   	busy = FALSE;
		   	
			dbg("Test1","send error!\n");
		   	post senddatatask();
		   }
	   }
  }
event void MilliTimer.fired()
{
	send_battery_info();
}
  event message_t* BeaconReceive.receive(message_t* msg,void* payload,uint8_t len)//接收，并执行任务
  {
          receiving = TRUE;
          //dbg("Test1","%u\n",len);
     atomic{
                    control_queue_receive_t* new_packet = NULL;
                     
                     new_packet = (control_queue_receive_t*)malloc(sizeof(control_queue_receive_t));
                     new_packet->message = msg;
                     new_packet->payload = payload;
                     battery = battery-5;//收到消息，电量-5
                     if(check_battery_change()!=1)
                     {
              	 send_battery_info();
                     }
                     if(len == sizeof(energymessage_t))
                     {
                          new_packet->classify = 1;
                     }
                     else if(len==sizeof(forwardant_t))
                     {
                          /*if(TOS_NODE_ID==1 || TOS_NODE_ID==2)
                          {
                                receiveantnum++;
                                dbg("Test1","NODE %u receive forward ant %u\n",TOS_NODE_ID,receiveantnum);
                          }*/
                          new_packet->classify = 2;
                     }
                     else if(len == sizeof(backwardant_t))
                     {
                          new_packet->classify = 3;
                     }
                     if(call ReceiveQueue.enqueue(new_packet)==SUCCESS)//这里可能将会出现问题
                     {
                            if(post Receivedatatask()!=SUCCESS)
                            {
                                 dbg("Test1","gg!\n");
                            }
                     }
                     else
                     {
                            dbg("Test1","shit!");
                     }
                     receiving = FALSE;
                     return msg;
             }
             
/*
       if(len == sizeof(energymessage_t))
       {
           new_packet = (control_queue_receive_t*)malloc(sizeof(control_queue_receive_t));
           new_packet->message = msg;
           new_packet->payload = payload;
           new_packet->classify = 1;
           if(call ReceiveQueue.enqueue(new_packet)==SUCCESS)//这里可能将会出现问题
           {
                    if(post Receivedatatask()!=SUCCESS)
                    {
		            dbg("Test1","gg!\n");
                    }
           }
           else
           {
	       dbg("Test1","shit!");
           }
           receiving = FALSE;
       }
    */   
    }



}

