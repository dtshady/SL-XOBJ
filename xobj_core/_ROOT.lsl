/*
	This is the root file, it ties together xobj core
	Whereas you probably don't want to change anything in this file in particular
	I'll still try to explain what things do
	
*/

// xobj_core comes with a couple of libraries, they are included
#include "xobj_core/libraries/libJas.lsl"
#include "xobj_core/libraries/libJasPre.lsl"
#include "xobj_core/libraries/partiCat.lsl"

// Sharedvars should be included by default, so it can be used by all projects at will
#include "xobj_core/classes/cl SharedVars.lsl" // SV headers


// These constants should be overwritten and defined in your _core.lsl file for each project
#ifndef PC_SALT
	// Define and set to any integer in your _core.lsl file, it will offset your playerchan. It's not recommended to use the same number for multiple projects.
	#define PC_SALT 0
#endif
#ifndef TOKEN_SALT
	// This is a secret code used to generate a hash. Define and set it to any string in your _core.lsl file
	#define TOKEN_SALT ""
#endif

// This generates a channel for each agent's scripts
integer playerChan(key id){
    return -llAbs((integer)("0x7"+llGetSubString((string)id, -7,-1))+PC_SALT);
}

// This generates a salted hash for your project. Feel free replace the content of this function with an algorithm of your own.
string getToken(key senderKey, key recipient, string saltrand){
	if(saltrand == "")saltrand = llGetSubString(llGenerateKey(),0,15);
	return saltrand+llGetSubString(llSHA1String((string)senderKey+(string)llGetOwnerKey(recipient)+TOKEN_SALT+saltrand),0,15);
}
// Returns "" on fail, else returns data


// Global events
// These are events that are project-wide, module events and methods can NOT be negative integers. As they are reserved for project-wide ones.
#define evt$SCRIPT_INIT -1		// NULL - Should be raised when a module is initialized
#define evt$TOUCH_START -2		// [(int)prim, (key)id] - Raised when an agent clicks the prim
#define evt$TOUCH_END -3		// [(int)prim, (key)id] - Raised when an agent release the click
#define evt$BUTTON_PRESS -4		// (int)level&edge - Raised when a CONTROL button is pressed down. The nr is a bitfield containing the CONTROL_* buttons that were pressed.
#define evt$BUTTON_RELEASE -5	// (int)~level&edge - Raised when a CONTROL button is released. The nr is a bitfield containing the CONTROL_* buttons that were released.


// nr Task definitions
// These are put into the nr field of llMessageLinked. Do NOT use negative integers if you're going to send your own link messages manually.
#define RUN_METHOD -1			// Basically what the runMethod() function does, use that
#define METHOD_CALLBACK -2		// == || == pretty much the same but sent as a callback
#define EVT_RAISED -3			// str = (string)data, id = (string)event - An event was raised. Runs the onEvt() function
#define RESET_ALL -4			// NULL - Resets all scripts in the project

// Standard methods
// These are standard methods used by package modules. Do not define module-specific methods as negative numbers.
#define stdMethod$insert -1		// callback = (int)success
#define stdMethod$remove -2		// callback = (int)amount_of_objects_removed
//#define stdMethod$interact -3	// [st Interact] - To sent an interact call to a prim (Removed, replaced with events)

// General methods.
// Putting CALLBACK_NONE in the callback field will prevent callbacks from being sent when raising a method
#define CALLBACK_NONE JSON_NULL
// Synonym
#define NORET CALLBACK_NONE
// TARG_NULL is just two empty strings
#define TARG_NULL "", ""
// Use this if you are making a call to a module that's not a package module, does not need to send a callback, and does not need to be called by name
#define TNN "", "", CALLBACK_NONE, ""

// Initiates the standard listen event, put it in state_entry of #ROOT script
initiateListen(){
	llListen(playerChan(llGetOwner()), "", "", "") ;
	#ifdef LISTEN_OVERRIDE 
	llListen(LISTEN_OVERRIDE,"","","");
	#endif
}

// Disregard these, they're just preprocessor shortcuts
#define stdObjCom(methodType, uuidOrLink, customTarg, className, data) llRegionSayTo(uuidOrLink, playerChan(llGetOwnerKey(uuidOrLink)), customTarg+getToken(llGetKey(), uuidOrLink, "")+(string)methodType+":"+className+llList2Json(JSON_ARRAY, data)) 
#define stdOmniCom(methodType, customTarg, className, data) llRegionSay(playerChan(llGetOwner()), customTarg+getToken(llGetKey(), llGetOwner(), "")+(string)methodType+":"+className+llList2Json(JSON_ARRAY, data)) 
#define stdIntCom(methodType, uuidOrLink, className, data) llMessageLinked((integer)uuidOrLink, methodType, className+llList2Json(JSON_ARRAY, data), "");
#define sendCallback(sender, senderScript, method, search, in, cbdata, cb) list CB_OP = [method, search, in, cbdata, llGetScriptName(), cb]; if(llStringLength(sender)!=36){stdIntCom(METHOD_CALLBACK,LINK_SET, senderScript, CB_OP);}else{ stdObjCom(METHOD_CALLBACK,sender, "*", senderScript, CB_OP);}


// This is the standard way to run a method on a module. See the readme files on how to use it properly.
runMethod(string uuidOrLink, string className, integer method, list data, string findObj, string in, string callback, string customTarg){
	list op = [method, findObj, in, llList2Json(JSON_ARRAY, data), llGetScriptName()];
	if(callback != JSON_NULL)op+=[callback];
	string pre = customTarg;
	if(pre == "")pre = "*";
	if((key)uuidOrLink){stdObjCom(RUN_METHOD, uuidOrLink, pre, className, op);}
	else{ stdIntCom(RUN_METHOD, uuidOrLink, className, op)}
}

// Tries to run a method on all viable scripts in the region
runOmniMethod(string className, integer method, list data, string findObj, string in, string callback, string customTarg){
	string pre = customTarg;
	if(pre == "")pre = "*";
	list op = [method, findObj, in, llList2Json(JSON_ARRAY, data), llGetScriptName()];
	if(callback != JSON_NULL)op+=[callback];
	stdOmniCom(RUN_METHOD, pre, className, op);
}

// Same as above, but is lets you limit by 96m, 20m, or 10m, reducing lag a little
runLimitMethod(string className, integer method, list data, string findObj, string in, string callback, string customTarg, float range){
	string pre = customTarg;
	if(pre == "")pre = "*";
	list op = [method, findObj, in, llList2Json(JSON_ARRAY, data), llGetScriptName()];
	if(callback != JSON_NULL)op+=[callback];
	if(range>96)stdOmniCom(RUN_METHOD, pre, className, op);
	else if(range>20)llShout(playerChan(llGetOwner()), pre+getToken(llGetKey(), llGetOwner(), "")+(string)RUN_METHOD+":"+className+llList2Json(JSON_ARRAY, op));
	else if(range>10)llSay(playerChan(llGetOwner()), pre+getToken(llGetKey(), llGetOwner(), "")+(string)RUN_METHOD+":"+className+llList2Json(JSON_ARRAY, op));
	else llSay(playerChan(llGetOwner()), pre+getToken(llGetKey(), llGetOwner(), "")+(string)RUN_METHOD+":"+className+llList2Json(JSON_ARRAY, op));
}

// Shortcut function to insert an object into a package module
insert(integer link, string className, list data, string callback){
	runMethod((string)link, className, stdMethod$insert, data, TARG_NULL, callback, "");
}
// Shortcut function to remove an object from a package module
remove(integer link, string className, string search, string in, string callback){
	runMethod((string)link, className, search, in, callback, "");
}

// Placeholder function for events. Copy paste this and fill it with code in each module that needs to listen to events.
onEvt(string script, integer evt, string data){
	
}

// Standard function to raise an event.
raiseEvent(integer evt, string data){
	llMessageLinked(LINK_SET, EVT_RAISED, llList2Json(JSON_ARRAY, [llGetScriptName(), data]), (string)evt);
}

// Code used to reset the linkset's scripts
#define resetAllOthers() llMessageLinked(LINK_SET, RESET_ALL, llGetScriptName(), "")
#define resetAll() llMessageLinked(LINK_SET, RESET_ALL, llGetScriptName(), ""); llResetScript()




 

 