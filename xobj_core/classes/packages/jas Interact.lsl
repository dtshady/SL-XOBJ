#define USE_EVENTS
#include "xobj_core/classes/jas Interact.lsl"
#include "xobj_core/classes/jas RLV.lsl"
#include "xobj_core/classes/jas Climb.lsl"
  
// List of additional (string)keys to allow
list additionalAllow;
integer BFL;
#define BFL_RECENT_CLICK 1      		// Recently interacted
#define BFL_OVERRIDE_DISPLAYED 0x2		// Override has been shown
#define BFL_PRIMSWIM_LEDGE 0x4			// Requires InteractConf$usePrimSwim set. Shows a message if you're at a ledge you can climb out from

#define TIMER_SEEK "a"
#define TIMER_RECENT_CLICK "c"

integer pInteract;

string targDesc;
key targ;
key real_key;						// If ROOT is used, then this is the sublink. You can use this global in onInteract
integer held;

list OVERRIDE;						// [(str)Override_text, (key)sender, (str)senderScript, (str)CB]



onEvt(string script, integer evt, list data){ 
	#ifdef USE_EVENT_OVERRIDE
	evt(script, evt, data);
	#endif
    if(script == "#ROOT"){
		if(evt == evt$BUTTON_RELEASE && llList2Integer(data,0)&(CONTROL_UP
		#ifdef InteractConf$ALLOW_ML_LCLICK
		| CONTROL_ML_LBUTTON
		#endif
		)
		){
			if(BFL&BFL_RECENT_CLICK){
				return;
			}
			if(!preInteract(targ))return;
			
			
			integer ainfo = llGetAgentInfo(llGetOwner());
			if(ainfo&AGENT_SITTING){
				if(ainfo&AGENT_SITTING){
					RLV$unsit(FALSE);
				}
				return;
			}
			
			
			
			BFL = BFL|BFL_RECENT_CLICK;
			multiTimer([TIMER_RECENT_CLICK, "", 
			#ifdef InteractConf$maxRate
			InteractConf$maxRate
			#else
			1
			#endif
			, FALSE]);
			
			
			if(OVERRIDE){
				
				onInteract("", llList2String(OVERRIDE, 0), []);						// Always run this before
				sendCallback(llList2Key(OVERRIDE, 1), llList2String(OVERRIDE, 2), InteractMethod$override, mkarr([llList2String(OVERRIDE, 0)]), llList2String(OVERRIDE, 3));
				return;
			}
			
			
			
			list actions = llParseString2List(targDesc, ["$$"], []);
			
			if(
				!llGetListLength(actions)
				#ifdef InteractConf$usePrimSwim
				&& ~BFL&BFL_PRIMSWIM_LEDGE
				#endif
			){
				return 
				#ifdef InteractConf$soundOnFail
					llPlaySound(InteractConf$soundOnFail, .25);
				#endif
				;
			}
			
			while(llGetListLength(actions)){
				string val = llList2String(actions,0);
				actions = llDeleteSubList(actions,0,0);
				list split = llParseString2List(val, ["$"], []);
				string task = llList2String(split, 0); 
				if(task == Interact$TASK_TELEPORT){
					vector to = (vector)llList2String(split,1); 
					to+=prPos(targ);
					RLV$cubeTask(SupportcubeBuildTeleport(to));
					raiseEvent(InteractEvt$TP, "");
				} 
				else if(task == Interact$TASK_PLAY_SOUND || task == Interact$TASK_TRIGGER_SOUND){
					key sound = llList2String(split,1);
					float vol = llList2Float(split,2);
					if(vol<=0)vol = 1;
					if(task == Interact$TASK_TRIGGER_SOUND)llTriggerSound(sound, vol);
					else llPlaySound(sound, vol);
				}
				else if(task == Interact$TASK_SITON){
					RLV$sitOn(targ, FALSE); 
				} 
				else if(task == Interact$TASK_CLIMB){ 
					Climb$start(targ, 
						(rotation)llList2String(split,1), // Rot offset 
						llList2String(split,2), // Anim passive
						llList2String(split,3), // Anim active
						llList2String(split,4), // anim_active_down, 
						llList2String(split,5), // anim_dismount_top, 
						llList2String(split,6), // anim_dismount_bottom, 
						llList2String(split,7), // nodes, 
						llList2String(split,8), // Climbspeed
						llList2String(split,9), // onStart
						llList2String(split,10) // onEnd
					);
				}else onInteract(targ, task, llList2List(split,1,-1));
			}
		}else if(evt == evt$BUTTON_HELD_SEC){
			integer btn = llList2Integer(data, 0);
			if(btn == CONTROL_UP)held = llList2Integer(data, 1);
		}else if(evt == evt$BUTTON_PRESS && llList2Integer(data,0)&CONTROL_UP)held = 0;
    }
	#ifdef InteractConf$usePrimSwim
	else if(script == "jas Primswim" && evt == PrimswimEvt$atLedge){
		if(llList2Integer(data,0))BFL = BFL|BFL_PRIMSWIM_LEDGE;
		else BFL = BFL&~BFL_PRIMSWIM_LEDGE;
	}
	#endif
	
}

timerEvent(string id, string data){
    if(id == TIMER_SEEK){
		
		// override is set, use the override text instead
		if(OVERRIDE){
			if(~BFL&BFL_OVERRIDE_DISPLAYED){
				BFL = BFL|BFL_OVERRIDE_DISPLAYED;
				onDesc(llGetOwner(), llList2String(OVERRIDE, 0));
			}
		}
		else if( llGetPermissions()&PERMISSION_TRACK_CAMERA){
            integer ainfo = llGetAgentInfo(llGetOwner());
            if(~ainfo&AGENT_SITTING){
                vector start;
                vector fwd = llRot2Fwd(llGetCameraRot())*3;
                if(ainfo&AGENT_MOUSELOOK){
                    start = llGetCameraPos();
                }else{
                    vector ascale = llGetAgentSize(llGetOwner());
                    start = llGetPos()+<0,0,ascale.z*.25>;
                }
				list ray = llCastRay(start, start+fwd, []);
    
                if(llList2Integer(ray,-1) > 0){
					
					key k = llList2Key(ray,0);
					
					if(~llListFindList(additionalAllow, [(string)k])){
						targ = llList2Key(ray,0);
						targDesc = "CUSTOM";
						onDesc(targ, "CUSTOM");
						return;
					}
						
					string td = prDesc(k);
					key real = k;
					#ifdef InteractConf$USE_ROOT
					k = prRoot(k);
					#else
					if(td == "ROOT"){
						k = prRoot(k);
						td = prDesc(k);
					}
					#endif

                    if(prRoot(llGetOwner()) != prRoot(k)){
						
                        
                        list descparse = llParseString2List(td, ["$$"], []);
        
                        list_shift_each(descparse, val, {
                            list parse = llParseString2List(val, ["$"], []);
                            if(llList2String(parse,0) == Interact$TASK_DESC){
                                targDesc = td;
                                targ = k;
								real_key = real;
                                onDesc(targ, llList2String(parse, 1));
                                return;
                            }
                        })
                    } 
                }
            }
            targ = "";
            targDesc = "";
			#ifdef PrimswimEvt$atLedge
			if(BFL&BFL_PRIMSWIM_LEDGE)targ = "_PRIMSWIM_CLIMB_";
			#endif
            onDesc(targ, targDesc);
        }
    }

    else if(id == TIMER_RECENT_CLICK){
        BFL = BFL&~BFL_RECENT_CLICK;
    }
}



default
{
    state_entry()
    {
        onInit();
		llSetMemoryLimit(llGetUsedMemory()*2);
		multiTimer([TIMER_SEEK, "", 0.25, TRUE]);
		if(llGetAttached())llRequestPermissions(llGetOwner(), PERMISSION_TRACK_CAMERA);
    }
    
    timer(){multiTimer([]);}
    
    #include "xobj_core/_LM.lsl" 
    /* 
        Included in all these calls:
        METHOD - (int)method
        PARAMS - (var)parameters
        SENDER_SCRIPT - (var)parameters
        CB - The callback you specified when you sent a task
        CB_DATA - Array of params to return in a callback
    */
    
    if(!method$byOwner)return;
	
    if(method$isCallback){
        return;
    }
        
	if(METHOD == InteractMethod$override){
	// Clear override displayed
		BFL = BFL&~BFL_OVERRIDE_DISPLAYED;
			
		if(method_arg(0) == "")
			OVERRIDE = [];
		else
			OVERRIDE = [method_arg(0), id, SENDER_SCRIPT, CB];
		
		return;
	}
    
    #define LM_BOTTOM  
    #include "xobj_core/_LM.lsl" 
    
    
}


