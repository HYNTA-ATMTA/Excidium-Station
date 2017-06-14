#define CHARS_PER_LINE 5
#define FONT_SIZE "5pt"
#define FONT_COLOR "#09f"
#define FONT_STYLE "Arial Black"
//  Code Notes: Combination of old brigdoor.dm code from rev4407 and the status_display.dm code
//  Date: 01/September/2010
//  Programmer: Veryinky

/obj/machinery/door_timer
	name = "Door Timer"
	icon = 'icons/obj/status_display.dmi'
	icon_state = "frame"
	desc = "A remote control for a door."
	req_access = list(access_brig)
	anchored = 1.0    		// can't pick it up
	density = 0       		// can walk through it.
	maptext_height = 26
	maptext_width = 32

	var/id = null     		// id of door it controls.
	var/releasetime = 0		// when world.timeofday reaches it - release the prisoner
	var/timing = 0    		// boolean, true/1 timer is on, false/0 means it's not timing
	var/picture_state		// icon_state of alert picture, if not displaying text/numbers
	var/timetoset = 0		// Used to set releasetime upon starting the timer
	var/obj/item/device/radio/Radio
	var/screen = 1

	var/detaineename = null
	var/detaineecrimes = ""
	var/list/comittedcrimes = list()
	var/suggestedbrigtime = 0
	var/list/possible_laws = list()
	var/printed = 0
	var/obj/item/weapon/paper/P
	var/list/obj/machinery/targets = list()
	var/datum/data/record/prisoner

///////////////////////////////////////////////////////ON SPAWN/////////////////////////////////////////////////

/obj/machinery/door_timer/initialize()
	..()
	Radio = new /obj/item/device/radio(src)
	Radio.listening = 0
	Radio.config(list("Security" = 0))
	Radio.follow_target = src

	pixel_x = ((dir & 3)? (0) : (dir == 4 ? 32 : -32))
	pixel_y = ((dir & 3)? (dir ==1 ? 24 : -32) : (0))

	spawn(20)
		for(var/obj/machinery/door/window/brigdoor/M in airlocks)
			if(M.id == id)
				targets += M

		for(var/obj/machinery/flasher/F in machines)
			if(F.id == id)
				targets += F

		for(var/obj/structure/closet/secure_closet/brig/C in world)
			if(C.id == id)
				targets += C

		for(var/obj/machinery/treadmill_monitor/T in machines)
			if(T.id == id)
				targets += T

		if(targets.len==0)
			stat |= BROKEN
		update_icon()

/obj/machinery/door_timer/Destroy()
	QDEL_NULL(Radio)
	prisoner = null
	targets.Cut()
	return ..()

///////////////////////////////////////////////////////CELL LOGS/////////////////////////////////////////////////

/obj/machinery/door_timer/proc/print_report() //Printing Cell Logs
	for(var/obj/machinery/computer/prisoner/C in prisoncomputer_list)
		P = new /obj/item/weapon/paper(C.loc)
		P.name = "[id] log - [detaineename] [worldtime2text()]"
		P.info =  "<center>[station_name()] - Security Department</center>"
		P.info += {"<center><b><h3>[id] - Brig record</h3></b></center>
					<center><b>Admission data:</b></small></center><br>
					<small><b>Log generated at:</b>		[worldtime2text()]<br>
					<b>Detainee:</b>		[detaineename]<br>
					<b>Duration:</b>		[timetoset/10] seconds<br>
					<b>Charge(s):</b>		[detaineecrimes]<br>
					<b>Arresting Officer:</b>		[usr.name]<br></small>
					<br>This log file was generated automatically upon activation of a cell timer.<br><hr>"}

		playsound(C.loc, "sound/goonstation/machines/printer_dotmatrix.ogg", 50, 1)
	cell_logs.Add(P)
	return 1

///////////////////////////////////////////////RECORD UPDATING/////////////////////////////////////////////////////

/obj/machinery/door_timer/proc/update_record()
	var/datum/data/record/R = find_security_record("name", detaineename)
	Radio.autosay("Detainee: [detaineename] has been incarcerated for; [timetoset/10] seconds for the charges of; [detaineecrimes]\
	Arresting Officer: [usr.name].[R ? "" : " Detainee record not found, manual record update required."]", name, "Security", list(z))

	if(R)
		prisoner = R
		R.fields["criminal"] = "Incarcerated"
		var/mob/living/carbon/human/M = usr
		var/rank = "UNKNOWN RANK"
		if(istype(M) && M.wear_id)
			var/obj/item/weapon/card/id/I = M.wear_id
			rank = I.assignment
		R.fields["comments"] = list()
		R.fields["comments"] += "Autogenerated by [name] on [current_date_string] [worldtime2text()]<BR>Sentenced to [timetoset/10] seconds for the charges of \"[detaineecrimes]\" by [rank] [usr.name]."
		update_all_mob_security_hud()

 ///////////////////////////////////////////////////////CRIMES AND MODIFIERS/////////////////////////////////////////////////

/obj/machinery/door_timer/proc/clearstringandtime() //Updating comitted crimes string list
	detaineecrimes = ""//Empty the string list so we can fill it again
	suggestedbrigtime = 0
	timetoset = 0
	for(var/datum/spacelaw/C in comittedcrimes)
		detaineecrimes += "[C.name]<br>"
		suggestedbrigtime += C.max_brig
		if(istype(C, /datum/spacelaw/modifiers/multiply/))
			var/newbrigtime = suggestedbrigtime * C.maxM_brig
			suggestedbrigtime += round(newbrigtime)
		timeset(suggestedbrigtime * 60)


/obj/machinery/door_timer/proc/add_charge(mob/user) //Adding Charges
	possible_laws.Cut()//Clear the LIST

	if(detaineename == "")
		add_name(usr)

	switch(alert("Select Space Law Category.", "Space Law", "Crimes", "Modifiers", "Custom", "Abort"))
		if("Abort")
			return
		if("Crimes")
			switch(alert("Select Article to add.", "Space Law", "Minor", "Medium", "Major", "Abort"))
				if("Minor")
					for(var/minorcrimes in subtypesof(/datum/spacelaw/minor))
						possible_laws += new minorcrimes()
				else if("Medium")
					for(var/mediumcrimes in subtypesof(/datum/spacelaw/medium))
						possible_laws += new mediumcrimes()
				else if("Major")
					for(var/majorcrimes in subtypesof(/datum/spacelaw/major/))
						possible_laws += new majorcrimes()
				else if("Abort")
					return
		if("Modifiers")
			for(var/modifiers in subtypesof(/datum/spacelaw/modifiers/))
				possible_laws += new modifiers()
		if("Custom")
			var/datum/spacelaw/S = new()
			S.name = input(user, "Please select custom article to add for [detaineename]") as null|text
			S.max_fine = input(user, "Please select amount to fine for [detaineename]") as num
			S.desc = S.name
			comittedcrimes.Add(S)
			clearstringandtime()
		if("Abort")
			return

	var/datum/spacelaw/selectedcrime = input(user, "Please select article to add for [detaineename]") as null|anything in possible_laws
	if(!isnull(selectedcrime))
		comittedcrimes.Add(selectedcrime)
		clearstringandtime()
	else
		return

/obj/machinery/door_timer/proc/remove_charge(mob/user) //Removing Charges
	if(comittedcrimes.len)
		var/datum/spacelaw/removecrime = input(usr, "Please select charge to remove for [detaineename]") as null|anything in comittedcrimes
		if(isnull(removecrime))
			to_chat(user,"<span class='warning'>Please select a proper charge to remove!</span>")
			return
		else
			comittedcrimes -= removecrime
			clearstringandtime()
	else
		to_chat(user,"<span class='warning'>No charges to remove!</span>")

/obj/machinery/door_timer/proc/add_name(mob/user)//Adding Name
	var/selectedname = input(user, "What is the name of the detainee?") as null|text
	if(selectedname == "")
		to_chat(user, "<span class='warning'>Please input a valid name! </span>")
		return
	else
		detaineename = selectedname

///////////////////////////////////////////////////////TIMING AND RUNNING/////////////////////////////////////////////////

/obj/machinery/door_timer/process()
	if(stat & (NOPOWER|BROKEN))
		return
	if(timing)
		if(timeleft() <= 0)
			Radio.autosay("Timer has expired. Releasing prisoner.", name, "Security", list(z))
			timer_end() // open doors, reset timer, clear status screen
			timing = 0
			. = PROCESS_KILL

		updateUsrDialog()
		update_icon()
	else
		timer_end()
		return PROCESS_KILL

/obj/machinery/door_timer/power_change()
	..()
	update_icon()

/obj/machinery/door_timer/proc/timer_start()
	playsound(src, 'sound/machines/chime.ogg', 50, 1)
	timing = 1
	screen = 0

	if(stat & (NOPOWER|BROKEN))
		return 0

	print_report()
	update_record()

	releasetime = world.timeofday + timetoset
	if(!(src in machine_processing))
		machine_processing += src

	for(var/obj/machinery/door/window/brigdoor/door in targets)
		if(door.density)
			continue
		spawn(0)
			door.close()

	for(var/obj/structure/closet/secure_closet/brig/C in targets)
		if(C.broken)
			continue
		if(C.opened && !C.close())
			continue
		C.locked = 1
		C.icon_state = C.icon_locked

	for(var/obj/machinery/treadmill_monitor/T in targets)
		T.total_joules = 0
		T.on = 1
	return 1

/obj/machinery/door_timer/proc/timer_end()
	if(stat & (NOPOWER|BROKEN))
		return 0

	comittedcrimes.Cut()
	detaineecrimes = ""
	detaineename = ""
	suggestedbrigtime = 0

	if(prisoner)
		prisoner.fields["criminal"] = "Released"
		update_all_mob_security_hud()
		prisoner = null

	for(var/obj/machinery/door/window/brigdoor/door in targets)
		if(!door.density)
			continue
		spawn(0)
			door.open()

	for(var/obj/structure/closet/secure_closet/brig/C in targets)
		if(C.broken)
			continue
		if(C.opened)
			continue
		C.locked = 0
		C.icon_state = C.icon_closed

	for(var/obj/machinery/treadmill_monitor/T in targets)
		if(!T.stat)
			T.redeem()
		T.on = 0

	releasetime = 0
	screen = 1
	timing = 0
	return 1
///////////////////////////////////////////////////////DISPLAYS/////////////////////////////////////////////////

/obj/machinery/door_timer/proc/timeleft()
	var/time = releasetime - world.timeofday
	if(time > MIDNIGHT_ROLLOVER / 2)
		time -= MIDNIGHT_ROLLOVER
	if(time < 0)
		return 0
	return time / 10

//Set timetoset
/obj/machinery/door_timer/proc/timeset(seconds)
	timetoset = seconds * 10
	if(timetoset <= 0)
		timetoset = 0
	return

/obj/machinery/door_timer/update_icon()
	if(stat & (NOPOWER))
		icon_state = "frame"
		return
	if(stat & (BROKEN))
		set_picture("ai_bsod")
		return
	if(timing)
		var/disp1 = id
		var/timeleft = timeleft()
		var/disp2 = "[add_zero(num2text((timeleft / 60) % 60),2)]~[add_zero(num2text(timeleft % 60), 2)]"
		if(length(disp2) > CHARS_PER_LINE)
			disp2 = "Error"
		update_display(disp1, disp2)
	else
		if(maptext)	maptext = ""

/obj/machinery/door_timer/proc/set_picture(state)
	picture_state = state
	overlays.Cut()
	overlays += image('icons/obj/status_display.dmi', icon_state=picture_state)

/obj/machinery/door_timer/proc/update_display(line1, line2)
	var/new_text = {"<div style="font-size:[FONT_SIZE];color:[FONT_COLOR];font:'[FONT_STYLE]';text-align:center;" valign="top">[line1]<br>[line2]</div>"}
	if(maptext != new_text)
		maptext = new_text

/obj/machinery/door_timer/proc/texticon(tn, px = 0, py = 0)
	var/image/I = image('icons/obj/status_display.dmi', "blank")
	var/len = lentext(tn)

	for(var/d = 1 to len)
		var/char = copytext(tn, len-d+1, len-d+2)
		if(char == " ")
			continue
		var/image/ID = image('icons/obj/status_display.dmi', icon_state=char)
		ID.pixel_x = -(d-1)*5 + px
		ID.pixel_y = py
		I.overlays += ID
	return I

///////////////////////////////////////////////////////UI/////////////////////////////////////////////////

/obj/machinery/door_timer/attack_ai(mob/user)
	interact(user)

/obj/machinery/door_timer/attack_ghost(mob/user)
	interact(user)

/obj/machinery/door_timer/attack_hand(mob/user)
	if(..())
		return
	interact(user)

/obj/machinery/door_timer/interact(mob/user)
	//Used for the 'time left' display
	var/second = round(timeleft() % 60)
	var/minute = round((timeleft() - second) / 60)
	//Used for 'set timer'
	var/setsecond = round((timetoset / 10) % 60)
	var/setminute = round(((timetoset / 10) - setsecond) / 60)
	//Used for storing the UI
	var/dat
	user.set_machine(src)

	dat = {"<center><h2>Timer System:<br>
			<b>Door [id]</b></h2></center><hr>"}

	if(screen)//Main Menu
		dat += {"<br><b>Detainee Name:</b>	<a href='?src=[UID()]'>[detaineename]</a>	<a href='?src=[UID()];pickname=1'>Set Name</a><br>
				<b>Charged with violation of:</b><br><a href='?src=[UID()]'>[detaineecrimes]</a><br>
				<b>Suggested Brig Time:	</b><a href='?src=[UID()]'>[suggestedbrigtime] minute(s)</a><br><hr>"}

		dat += "<h2><b>Crimes and modifiers</b></h2>"
		dat += "<a href='?src=[UID()];pickcharges=1'>Add</a><br>"
		dat += "<a href='?src=[UID()];removecharges=1'>Remove</a>"
		dat += "<h2><a href='?src=[UID()];timingstart=1'>Activate Timer and close door</a></h2>"
		dat += "Set Timer: [(setminute ? text("[setminute]:") : null)][setsecond]  <a href='?src=[UID()];change=1'>Set</a><br/>"
		dat += "<a href='?src=[UID()];tp=-60'>-</a> <a href='?src=[UID()];tp=-1'>-</a> <a href='?src=[UID()];tp=1'>+</a> <A href='?src=[UID()];tp=60'>+</a><br>"

	if(!screen) //Prisoner Menu
		dat += "<center><h1>Time Left: [(minute ? text("[minute]:") : null)][second]</h1></center>"
		dat += {"<center><b><h2>Current Detainee Information</h2></b><hr></center><br><b>Detainee Name:	</b>[detaineename]<br><b>Charged with violation of:	</b><br>[detaineecrimes]
				<b>Duration brigged:	</b>[suggestedbrigtime]<br><b>Brigged by:	</b>[usr.name]"}
		dat += "<hr><h2><br><a href='?src=[UID()];timingstop=1'>Stop Timer and open door</a></h2>"
		dat += "Set Timer: [(setminute ? text("[setminute]:") : null)][setsecond]  <a href='?src=[UID()];change=1'>Set Time</a><br/>"

	//Mounted Flash Controls
	for(var/obj/machinery/flasher/F in targets)
		if(F.last_flash && (F.last_flash + 150) > world.time)
			dat += "<br><A href='?src=[UID()];flash=1'>Flash Charging</A>"
		else
			dat += "<br><A href='?src=[UID()];flash=1'>Activate Flash</A>"

	//Locker Controls
	for(var/obj/structure/closet/secure_closet/brig/C in targets)
		if(C.opened)
			dat += "<br><A href='?src=[UID()];closet=1'>Close Locker</A>"
		else
			dat += "<br><A href='?src=[UID()];closet=1'>Open Locker</A>"

	usr.set_machine(src)
	var/datum/browser/popup = new(user, "door_timer", name, 400, 500)
	popup.set_content(dat)
	popup.open()

/obj/machinery/door_timer/Topic(href, href_list)
	..()
	if(!allowed(usr) && !usr.can_admin_interact())
		return 1

	if(href_list["timingstart"])
		if(!detaineecrimes | isnull(detaineename) | timetoset == 0)
			visible_message("<span class='warning'>The [src] buzzes. Cannot activate without all information inputted.</span>")
			playsound(loc, 'sound/machines/buzz-sigh.ogg', 50, 0)
		else
			timer_start()

	if(href_list["timingstop"])
		switch(alert("Are you sure you wish to stop the cell timer? All data will be cleared", "Stop Cell Timer?", "Stop", "Abort"))
			if("Stop")
				Radio.autosay("Timer stopped manually by [usr.name].", name, "Security", list(z))
				timer_end()
			if("Abort")
				return

	if(href_list["tp"])  //adjust timer, close door if not already closed
		var/tp = text2num(href_list["tp"])
		var/addtime = (timetoset / 10)
		addtime += tp
		addtime = min(max(round(addtime), 0), 3600)
		timeset(addtime)

	if(href_list["change"])
		var/newtime = input(usr, "How many minutes would you like to set the timer to(minutes)?") as num
		timeset(newtime * 60)

	if(href_list["flash"]) //Flash Button
		for(var/obj/machinery/flasher/F in targets)
			F.flash()

	if(href_list["closet"]) //Closet Button
		for(var/obj/structure/closet/secure_closet/brig/C in targets)
			if(C.broken)
				return
			if(C.opened)
				C.close()
				C.icon_state = C.icon_locked
				C.locked = 1
			else
				C.locked = 0
				C.open()

	if(href_list["pickname"]) //Input Name Button
		add_name(usr)

	if(href_list["pickcharges"]) //Add Charges Button
		add_charge(usr)

	if(href_list["removecharges"]) //Remove Charges Charges Button
		remove_charge(usr)

	add_fingerprint(usr)
	updateUsrDialog()
	update_icon()

/obj/machinery/door_timer/cell_1
	name = "Cell 1"
	id = "Cell 1"
	dir = 2
	pixel_y = -32

/obj/machinery/door_timer/cell_2
	name = "Cell 2"
	id = "Cell 2"
	dir = 2
	pixel_y = -32

/obj/machinery/door_timer/cell_3
	name = "Cell 3"
	id = "Cell 3"
	dir = 2
	pixel_y = -32

/obj/machinery/door_timer/cell_4
	name = "Cell 4"
	id = "Cell 4"
	dir = 2
	pixel_y = -32

/obj/machinery/door_timer/cell_5
	name = "Cell 5"
	id = "Cell 5"
	dir = 2
	pixel_y = -32

/obj/machinery/door_timer/cell_6
	name = "Cell 6"
	id = "Cell 6"
	dir = 4
	pixel_x = 32

#undef FONT_SIZE
#undef FONT_COLOR
#undef FONT_STYLE
#undef CHARS_PER_LINE