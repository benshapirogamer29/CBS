/mob/CanPass(atom/movable/mover, turf/target, height=0)
	if(height==0)
		return 1
	if(istype(mover, /obj/item/projectile) || mover.throwing)
		return (!density || lying)
	if(mover.checkpass(PASSMOB))
		return 1
	if(buckled == mover)
		return 1
	if(ismob(mover))
		var/mob/moving_mob = mover
		if((other_mobs && moving_mob.other_mobs))
			return 1
		if(mover == buckled_mob)
			return 1
	return (!mover.density || !density || lying)

//The byond version of these verbs wait for the next tick before acting.
//	instant verbs however can run mid tick or even during the time between ticks.
/client/verb/moveup()
	set name = ".moveup"
	set instant = 1
	Move(get_step(mob, NORTH), NORTH)

/client/verb/movedown()
	set name = ".movedown"
	set instant = 1
	Move(get_step(mob, SOUTH), SOUTH)

/client/verb/moveright()
	set name = ".moveright"
	set instant = 1
	Move(get_step(mob, EAST), EAST)

/client/verb/moveleft()
	set name = ".moveleft"
	set instant = 1
	Move(get_step(mob, WEST), WEST)


/client/Northeast()
	swap_hand()
	return


/client/Southeast()
	attack_self()
	return


/client/Southwest()
	if(iscarbon(usr))
		var/mob/living/carbon/C = usr
		C.toggle_throw_mode()
	else if(isrobot(usr))
		var/mob/living/silicon/robot/R = usr
		var/module = R.get_selected_module()
		if(!module)
			to_chat(usr, "<span class='warning'>You have no module selected.</span>")
			return
		R.cycle_modules()
		R.uneq_numbered(module)
	else
		to_chat(usr, "<span class='warning'>This mob type cannot throw items.</span>")
	return


/client/Northwest()
	if(iscarbon(usr))
		var/mob/living/carbon/C = usr
		if(!C.get_active_hand())
			to_chat(usr, "<span class='warning'>You have nothing to drop in your hand.</span>")
			return
		drop_item()
	else if(isrobot(usr))
		var/mob/living/silicon/robot/R = usr
		if(!R.get_selected_module())
			to_chat(usr, "<span class='warning'>You have no module selected.</span>")
			return
		R.deselect_module(R.get_selected_module())
	else
		to_chat(usr, "<span class='warning'>This mob type cannot drop items.</span>")
	return

//This gets called when you press the delete button.
/client/verb/delete_key_pressed()
	set hidden = 1

	if(!usr.pulling)
		to_chat(usr, "<span class='notice'>You are not pulling anything.</span>")
		return
	usr.stop_pulling()

/client/verb/swap_hand()
	set hidden = 1
	if(istype(mob, /mob/living/carbon))
		mob:swap_hand()
	if(istype(mob,/mob/living/silicon/robot))
		var/mob/living/silicon/robot/R = mob
		R.cycle_modules()
	return



/client/verb/attack_self()
	set hidden = 1
	if(mob)
		mob.mode()
	return


/client/verb/toggle_throw_mode()
	set hidden = 1
	if(iscarbon(mob))
		var/mob/living/carbon/C = mob
		C.toggle_throw_mode()
	else
		to_chat(usr, "<span class='danger'>This mob type cannot throw items.</span>")


/client/verb/drop_item()
	set hidden = 1
	if(!isrobot(mob))
		mob.drop_item_v()
	return


/client/Center()
	/* No 3D movement in 2D spessman game. dir 16 is Z Up
	if(isobj(mob.loc))
		var/obj/O = mob.loc
		if(mob.canmove)
			return O.relaymove(mob, 16)
	*/
	return



/client/proc/Move_object(direct)
	if(mob && mob.control_object)
		if(mob.control_object.density)
			step(mob.control_object, direct)
			if(!mob.control_object)
				return
			mob.control_object.setDir(direct)
		else
			mob.control_object.forceMove(get_step(mob.control_object, direct))
	return


/client/Move(n, direct)
	if(world.time < move_delay)
		return

	move_delay = world.time + world.tick_lag //this is here because Move() can now be called multiple times per tick
	if(!mob || !mob.loc)
		return 0

	if(mob.notransform)
		return 0 //This is sota the goto stop mobs from moving var

	if(mob.control_object)
		return Move_object(direct)

	if(!isliving(mob))
		return mob.Move(n, direct)

	if(mob.stat == DEAD)
		mob.ghostize()
		return 0

	if(moving)
		return 0

	if(isliving(mob))
		var/mob/living/L = mob
		if(L.incorporeal_move)//Move though walls
			Process_Incorpmove(direct)
			return

	if(mob.remote_control) //we're controlling something, our movement is relayed to it
		return mob.remote_control.relaymove(mob, direct)

	if(isAI(mob))
		if(istype(mob.loc, /obj/item/device/aicard))
			var/obj/O = mob.loc
			return O.relaymove(mob, direct) // aicards have special relaymove stuff
		return AIMove(n, direct, mob)


	if(Process_Grab())
		return

	if(mob.buckled) //if we're buckled to something, tell it we moved.
		return mob.buckled.relaymove(mob, direct)

	if(!mob.canmove)
		return

	if(!mob.lastarea)
		mob.lastarea = get_area(mob.loc)

	if(isobj(mob.loc) || ismob(mob.loc)) //Inside an object, tell it we moved
		var/atom/O = mob.loc
		return O.relaymove(mob, direct)

	if(!mob.Process_Spacemove(direct))
		return 0

	if(mob.restrained()) // Why being pulled while cuffed prevents you from moving
		for(var/mob/M in orange(1, mob))
			if(M.pulling == mob)
				if(!M.incapacitated() && mob.Adjacent(M))
					to_chat(src, "<span class='warning'>You're restrained! You can't move!</span>")
					move_delay = world.time + 10
					return 0
				else
					M.stop_pulling()


	//We are now going to move
	moving = 1
	move_delay = mob.movement_delay() + world.time
	mob.last_movement = world.time

	if(locate(/obj/item/weapon/grab, mob))
		move_delay = max(move_delay, world.time + 7)
		var/list/L = mob.ret_grab()
		if(istype(L, /list))
			if(L.len == 2)
				L -= mob
				var/mob/M = L[1]
				if(M)
					if((get_dist(mob, M) <= 1 || M.loc == mob.loc))
						var/turf/prev_loc = mob.loc
						. = ..()
						if(M && isturf(M.loc)) // Mob may get deleted during parent call
							var/diag = get_dir(mob, M)
							if((diag - 1) & diag)
							else
								diag = null
							if((get_dist(mob, M) > 1 || diag))
								step(M, get_dir(M.loc, prev_loc))
			else
				for(var/mob/M in L)
					M.other_mobs = 1
					if(mob != M)
						M.animate_movement = 3
				for(var/mob/M in L)
					spawn(0)
						step(M, direct)
						return
					spawn(1)
						M.other_mobs = null
						M.animate_movement = 2
						return

	else if(mob.confused)
		step(mob, pick(cardinal))
	else
		. = ..()

	for(var/obj/item/weapon/grab/G in mob)
		if(G.state == GRAB_NECK)
			mob.setDir(reverse_dir[direct])
		G.adjust_position()
	for(var/obj/item/weapon/grab/G in mob.grabbed_by)
		G.adjust_position()

	moving = 0
	if(mob && .)
		if(mob.throwing)
			mob.throwing.finalize(FALSE)

	for(var/obj/O in mob)
		O.on_mob_move(direct, mob)





///Process_Grab()
///Called by client/Move()
///Checks to see if you are being grabbed and if so attemps to break it
/client/proc/Process_Grab()
	if(mob.grabbed_by.len)
		var/list/grabbing = list()

		if(istype(mob.l_hand, /obj/item/weapon/grab))
			var/obj/item/weapon/grab/G = mob.l_hand
			grabbing += G.affecting

		if(istype(mob.r_hand, /obj/item/weapon/grab))
			var/obj/item/weapon/grab/G = mob.r_hand
			grabbing += G.affecting

		for(var/X in mob.grabbed_by)
			var/obj/item/weapon/grab/G = X
			switch(G.state)

				if(GRAB_PASSIVE)
					if(!grabbing.Find(G.assailant)) //moving always breaks a passive grab unless we are also grabbing our grabber.
						qdel(G)

				if(GRAB_AGGRESSIVE)
					move_delay = world.time + 10
					if(!prob(25))
						return 1
					mob.visible_message("<span class='danger'>[mob] has broken free of [G.assailant]'s grip!</span>")
					qdel(G)

				if(GRAB_NECK)
					move_delay = world.time + 10
					if(!prob(5))
						return 1
					mob.visible_message("<span class='danger'>[mob] has broken free of [G.assailant]'s headlock!</span>")
					qdel(G)
	return 0


///Process_Incorpmove
///Called by client/Move()
///Allows mobs to run though walls
/client/proc/Process_Incorpmove(direct)
	var/turf/mobloc = get_turf(mob)
	if(!isliving(mob))
		return
	var/mob/living/L = mob
	switch(L.incorporeal_move)
		if(1)
			L.forceMove(get_step(L, direct))
			L.dir = direct
		if(2)
			if(prob(50))
				var/locx
				var/locy
				switch(direct)
					if(NORTH)
						locx = mobloc.x
						locy = (mobloc.y+2)
						if(locy>world.maxy)
							return
					if(SOUTH)
						locx = mobloc.x
						locy = (mobloc.y-2)
						if(locy<1)
							return
					if(EAST)
						locy = mobloc.y
						locx = (mobloc.x+2)
						if(locx>world.maxx)
							return
					if(WEST)
						locy = mobloc.y
						locx = (mobloc.x-2)
						if(locx<1)
							return
					else
						return
				L.forceMove(locate(locx,locy,mobloc.z))
				spawn(0)
					var/limit = 2//For only two trailing shadows.
					for(var/turf/T in getline(mobloc, L.loc))
						spawn(0)
							anim(T,L,'icons/mob/mob.dmi',,"shadow",,L.dir)
						limit--
						if(limit<=0)	break
			else
				spawn(0)
					anim(mobloc,mob,'icons/mob/mob.dmi',,"shadow",,L.dir)
				L.forceMove(get_step(L, direct))
			L.dir = direct
		if(3) //Incorporeal move, but blocked by holy-watered tiles
			var/turf/simulated/floor/stepTurf = get_step(L, direct)
			if(stepTurf.flags & NOJAUNT)
				to_chat(L, "<span class='warning'>Holy energies block your path.</span>")
				L.notransform = 1
				spawn(2)
					L.notransform = 0
			else
				L.forceMove(get_step(L, direct))
				L.dir = direct
	return 1


///Process_Spacemove
///Called by /client/Move()
///For moving in space
///Return 1 for movement 0 for none
/mob/Process_Spacemove(movement_dir = 0)
	if(..())
		return 1
	var/atom/movable/backup = get_spacemove_backup()
	if(backup)
		if(istype(backup) && movement_dir && !backup.anchored)
			var/opposite_dir = turn(movement_dir, 180)
			if(backup.newtonian_move(opposite_dir)) //You're pushing off something movable, so it moves
				to_chat(src, "<span class='notice'>You push off of [backup] to propel yourself.</span>")
		return 1
	return 0

/mob/get_spacemove_backup()
	for(var/A in orange(1, get_turf(src)))
		if(isarea(A))
			continue
		else if(isturf(A))
			var/turf/turf = A
			if(istype(turf, /turf/space))
				continue
			if(!turf.density && !mob_negates_gravity())
				continue
			return A
		else
			var/atom/movable/AM = A
			if(AM == buckled) //Kind of unnecessary but let's just be sure
				continue
			if(!AM.CanPass(src) || AM.density)
				if(AM.anchored)
					return AM
				if(pulling == AM)
					continue
				. = AM


/mob/proc/mob_has_gravity(turf/T)
	return has_gravity(src, T)

/mob/proc/mob_negates_gravity()
	return 0

/mob/proc/Move_Pulled(atom/A)
	if(!canmove || restrained() || !pulling)
		return
	if(pulling.anchored)
		return
	if(!pulling.Adjacent(src))
		return
	if(A == loc && pulling.density)
		return
	if(!Process_Spacemove(get_dir(pulling.loc, A)))
		return
	if(ismob(pulling))
		var/mob/M = pulling
		var/atom/movable/t = M.pulling
		M.stop_pulling()
		step(pulling, get_dir(pulling.loc, A))
		if(M)
			M.start_pulling(t)
	else
		step(pulling, get_dir(pulling.loc, A))
	return

/mob/proc/update_gravity()
	return
