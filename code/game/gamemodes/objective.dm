var/global/list/all_objectives = list()

var/list/potential_theft_objectives = subtypesof(/datum/theft_objective) - /datum/theft_objective/steal - /datum/theft_objective/number

/datum/objective
	var/datum/mind/owner = null			//Who owns the objective.
	var/explanation_text = "Nothing"	//What that person is supposed to do.
	var/datum/mind/target = null		//If they are focused on a particular person.
	var/target_amount = 0				//If they are focused on a particular number. Steal objectives have their own counter.
	var/completed = 0					//currently only used for custom objectives.
	var/martyr_compatible = 0			//If the objective is compatible with martyr objective, i.e. if you can still do it while dead.

/datum/objective/New(var/text)
	all_objectives |= src
	if(text)
		explanation_text = text

/datum/objective/Destroy()
	all_objectives -= src
	return ..()

/datum/objective/proc/check_completion()
	return completed

/datum/objective/proc/is_invalid_target(datum/mind/possible_target)
	if(possible_target == owner)
		return TARGET_INVALID_IS_OWNER
	if(!ishuman(possible_target.current))
		return TARGET_INVALID_NOT_HUMAN
	if(!possible_target.current.stat == DEAD)
		return TARGET_INVALID_DEAD
	if(!possible_target.key)
		return TARGET_INVALID_NOCKEY

/datum/objective/proc/find_target()
	var/list/possible_targets = list()
	for(var/datum/mind/possible_target in ticker.minds)
		if(is_invalid_target(possible_target))
			continue

		possible_targets += possible_target

	if(possible_targets.len > 0)
		target = pick(possible_targets)


/datum/objective/assassinate
	martyr_compatible = 1

/datum/objective/assassinate/find_target()
	..()
	if(target && target.current)
		explanation_text = "Assassine [target.current.real_name], o [target.assigned_role]."
	else
		explanation_text = "Objetivo livre"

/datum/objective/assassinate/check_completion()
	if(target && target.current)
		if(target.current.stat == DEAD)
			return 1
		if(issilicon(target.current) || isbrain(target.current)) //Borgs/brains/AIs count as dead for traitor objectives. --NeoFite
			return 1
		if(!target.current.ckey)
			return 1
		return 0
	return 1


/datum/objective/mutiny
	martyr_compatible = 1

/datum/objective/mutiny/find_target()
	..()
	if(target && target.current)
		explanation_text = "Assassine [target.current.real_name], o [target.assigned_role]."
	else
		explanation_text = "Objetivo livre"
	return target

/datum/objective/mutiny/check_completion()
	if(target && target.current)
		if(target.current.stat == DEAD || !ishuman(target.current) || !target.current.ckey || !target.current.client)
			return 1
		var/turf/T = get_turf(target.current)
		if(T && !is_station_level(T.z))			//If they leave the station they count as dead for this
			return 1
		return 0
	return 1

/datum/objective/maroon
	martyr_compatible = 1

/datum/objective/maroon/find_target()
	..()
	if(target && target.current)
		explanation_text = "Previna que [target.current.real_name], o [target.assigned_role] escape vivo."
	else
		explanation_text = "Objetivo livre"
	return target

/datum/objective/maroon/check_completion()
	if(target && target.current)
		if(target.current.stat == DEAD)
			return 1
		if(!target.current.ckey)
			return 1
		if(issilicon(target.current))
			return 1
		if(isbrain(target.current))
			return 1
		var/turf/T = get_turf(target.current)
		if(is_admin_level(T.z))
			return 0
		return 1
	return 1


/datum/objective/debrain //I want braaaainssss
	martyr_compatible = 0

/datum/objective/debrain/find_target()
	..()
	if(target && target.current)
		explanation_text = "Roube o cerebro de [target.current.real_name] o [target.assigned_role]."
	else
		explanation_text = "Objetivo livre"
	return target


/datum/objective/debrain/check_completion()
	if(!target)//If it's a free objective.
		return 1
	if(!owner.current || owner.current.stat == DEAD)
		return 0
	if(!target.current || !isbrain(target.current))
		return 0
	var/atom/A = target.current
	while(A.loc)			//check to see if the brainmob is on our person
		A = A.loc
		if(A == owner.current)
			return 1
	return 0


/datum/objective/protect //The opposite of killing a dude.
	martyr_compatible = 1

/datum/objective/protect/find_target()
	..()
	if(target && target.current)
		explanation_text = "Proteja [target.current.real_name], o [target.assigned_role]."
	else
		explanation_text = "Objetivo livre"
	return target

/datum/objective/protect/check_completion()
	if(!target) //If it's a free objective.
		return 1
	if(target.current)
		if(target.current.stat == DEAD)
			return 0
		if(issilicon(target.current))
			return 0
		if(isbrain(target.current))
			return 0
		return 1
	return 0

/datum/objective/protect/mindslave //subytpe for mindslave implants


/datum/objective/hijack
	martyr_compatible = 0 //Technically you won't get both anyway.
	explanation_text = "Sequestre a shuttle e escape, nao deixe que ninguem leal a o Nanostrasen que esteja a bordo sobreviva. \
	Agentes do sindicato, e inimigos da Nanostrasen, seja ciborg, ou ate mesmo animal, podem ficar vivos"

/datum/objective/hijack/check_completion()
	if(!owner.current || owner.current.stat)
		return 0
	if(shuttle_master.emergency.mode < SHUTTLE_ENDGAME)
		return 0
	if(issilicon(owner.current))
		return 0

	var/area/A = get_area(owner.current)
	if(shuttle_master.emergency.areaInstance != A)
		return 0

	return shuttle_master.emergency.is_hijacked()

/datum/objective/hijackclone
	explanation_text = "Sequestre a shuttle garantindo que voc� (ou suas c�pias) escape vivo."
	martyr_compatible = 0

/datum/objective/hijackclone/check_completion()
	if(!owner.current)
		return 0
	if(shuttle_master.emergency.mode < SHUTTLE_ENDGAME)
		return 0

	var/area/A = shuttle_master.emergency.areaInstance

	for(var/mob/living/player in player_list) //Make sure nobody else is onboard
		if(player.mind && player.mind != owner)
			if(player.stat != DEAD)
				if(issilicon(player))
					continue
				if(get_area(player) == A)
					if(player.real_name != owner.current.real_name && !istype(get_turf(player.mind.current), /turf/simulated/shuttle/floor4))
						return 0

	for(var/mob/living/player in player_list) //Make sure at least one of you is onboard
		if(player.mind && player.mind != owner)
			if(player.stat != DEAD)
				if(issilicon(player))
					continue
				if(get_area(player) == A)
					if(player.real_name == owner.current.real_name && !istype(get_turf(player.mind.current), /turf/simulated/shuttle/floor4))
						return 1
	return 0

/datum/objective/block
	explanation_text = "Nao permita que nenhuma forma de vida, seja ela ciborgue, IA, ou pIA permanecam vivos."
	martyr_compatible = 1

/datum/objective/block/check_completion()
	if(!istype(owner.current, /mob/living/silicon))
		return 0
	if(shuttle_master.emergency.mode < SHUTTLE_ENDGAME)
		return 0
	if(!owner.current)
		return 0

	var/area/A = shuttle_master.emergency.areaInstance
	var/list/protected_mobs = list(/mob/living/silicon/ai, /mob/living/silicon/pai, /mob/living/silicon/robot)

	for(var/mob/living/player in player_list)
		if(player.type in protected_mobs)
			continue

		if(player.mind && player.stat != DEAD)
			if(get_area(player) == A)
				return 0

	return 1

/datum/objective/escape
	explanation_text = "Escape da esta��o por um pod de emergencia ou pela shuttle, vivo e livre."

/datum/objective/escape/check_completion()
	if(issilicon(owner.current))
		return 0
	if(isbrain(owner.current))
		return 0
	if(!owner.current || owner.current.stat == DEAD)
		return 0
	if(ticker.force_ending) //This one isn't their fault, so lets just assume good faith
		return 1
	if(ticker.mode.station_was_nuked) //If they escaped the blast somehow, let them win
		return 1
	if(shuttle_master.emergency.mode < SHUTTLE_ENDGAME)
		return 0
	var/turf/location = get_turf(owner.current)
	if(!location)
		return 0

	if(istype(location, /turf/simulated/shuttle/floor4)) // Fails traitors if they are in the shuttle brig -- Polymorph
		return 0

	if(location.onCentcom() || location.onSyndieBase())
		return 1

	return 0


/datum/objective/escape/escape_with_identity
	var/target_real_name // Has to be stored because the target's real_name can change over the course of the round

/datum/objective/escape/escape_with_identity/find_target()
	var/list/possible_targets = list() //Copypasta because NO_DNA races, yay for snowflakes.
	for(var/datum/mind/possible_target in ticker.minds)
		if(possible_target != owner && ishuman(possible_target.current) && (possible_target.current.stat != DEAD) && possible_target.current.client)
			var/mob/living/carbon/human/H = possible_target.current
			if(!(NO_DNA in H.species.species_traits))
				possible_targets += possible_target
	if(possible_targets.len > 0)
		target = pick(possible_targets)
	if(target && target.current)
		target_real_name = target.current.real_name
		explanation_text = "Escape pela shuttle ou pod de emergencia com a indentidade de [target_real_name], o [target.assigned_role] usando o cartao de indentificacao do alvo."
	else
		explanation_text = "Free Objective"

/datum/objective/escape/escape_with_identity/check_completion()
	if(!target_real_name)
		return 1
	if(!ishuman(owner.current))
		return 0
	var/mob/living/carbon/human/H = owner.current
	if(..())
		if(H.dna.real_name == target_real_name)
			if(H.get_id_name()== target_real_name)
				return 1
	return 0

/datum/objective/die
	explanation_text = "Morreu gloriosamente."

/datum/objective/die/check_completion()
	if(!owner.current || owner.current.stat == DEAD || isbrain(owner.current))
		return 1
	if(issilicon(owner.current) && owner.current != owner.original)
		return 1
	return 0



/datum/objective/survive
	explanation_text = "Permaneceu vivo ate o final(parabens seu merda)"

/datum/objective/survive/check_completion()
	if(!owner.current || owner.current.stat == DEAD || isbrain(owner.current))
		return 0		//Brains no longer win survive objectives. --NEO
	if(issilicon(owner.current) && owner.current != owner.original)
		return 0
	return 1

/datum/objective/nuclear
	explanation_text = "Destrua a estacao com o dispositivo nuclear."
	martyr_compatible = 1



/datum/objective/steal
	var/datum/theft_objective/steal_target
	martyr_compatible = 0

/datum/objective/steal/find_target()
	var/loop=50
	while(!steal_target && loop > 0)
		loop--
		var/thefttype = pick(potential_theft_objectives)
		var/datum/theft_objective/O = new thefttype
		if(owner.assigned_role in O.protected_jobs)
			continue
		if(O.flags & 2)
			continue
		steal_target=O
		explanation_text = "Roube [O]."
		return
	explanation_text = "Objetivo livre."


/datum/objective/steal/proc/select_target()
	var/list/possible_items_all = potential_theft_objectives+"custom"
	var/new_target = input("Select target:", "Objective target", null) as null|anything in possible_items_all
	if(!new_target) return
	if(new_target == "custom")
		var/datum/theft_objective/O=new
		O.typepath = input("Select type:","Type") as null|anything in typesof(/obj/item)
		if(!O.typepath) return
		var/tmp_obj = new O.typepath
		var/custom_name = tmp_obj:name
		qdel(tmp_obj)
		O.name = sanitize(copytext(input("Enter target name:", "Objective target", custom_name) as text|null,1,MAX_NAME_LEN))
		if(!O.name) return
		steal_target = O
		explanation_text = "Roube [O.name]."
	else
		steal_target = new new_target
		explanation_text = "Roube [steal_target.name]."
	return steal_target

/datum/objective/steal/check_completion()
	if(!steal_target)
		return 1 // Free Objective

	var/list/all_items = owner.current.GetAllContents()

	for(var/obj/I in all_items)
		if(istype(I, steal_target.typepath))
			return steal_target.check_special_completion(I)
		if(I.type in steal_target.altitems)
			return steal_target.check_special_completion(I)


/datum/objective/steal/exchange
	martyr_compatible = 0

/datum/objective/steal/exchange/proc/set_faction(var/faction,var/otheragent)
	target = otheragent
	var/datum/theft_objective/unique/targetinfo
	if(faction == "red")
		targetinfo = new /datum/theft_objective/unique/docs_blue
	else if(faction == "blue")
		targetinfo = new /datum/theft_objective/unique/docs_red
	explanation_text = "Adquira [targetinfo.name] que esta com [target.current.real_name], o [target.assigned_role] e agente do sindicato"
	steal_target = targetinfo

/datum/objective/steal/exchange/backstab
/datum/objective/steal/exchange/backstab/set_faction(var/faction)
	var/datum/theft_objective/unique/targetinfo
	if(faction == "red")
		targetinfo = new /datum/theft_objective/unique/docs_red
	else if(faction == "blue")
		targetinfo = new /datum/theft_objective/unique/docs_blue
	explanation_text = "Nao disista ou perca [targetinfo.name]."
	steal_target = targetinfo

/datum/objective/download
/datum/objective/download/proc/gen_amount_goal()
	target_amount = rand(10,20)
	explanation_text = "Baixando [target_amount] niveis de seguran�a."
	return target_amount


/datum/objective/download/check_completion()
	return 0



/datum/objective/capture
/datum/objective/capture/proc/gen_amount_goal()
	target_amount = rand(5,10)
	explanation_text = "Acumule [target_amount] pontos de captura."
	return target_amount


/datum/objective/capture/check_completion()//Basically runs through all the mobs in the area to determine how much they are worth.
	return 0




/datum/objective/absorb
/datum/objective/absorb/proc/gen_amount_goal(var/lowbound = 4, var/highbound = 6)
	target_amount = rand (lowbound,highbound)
	if(ticker)
		var/n_p = 1 //autowin
		if(ticker.current_state == GAME_STATE_SETTING_UP)
			for(var/mob/new_player/P in player_list)
				if(P.client && P.ready && P.mind != owner)
					if(P.client.prefs && (P.client.prefs.species == "Machine")) // Special check for species that can't be absorbed. No better solution.
						continue
					n_p++
		else if(ticker.current_state == GAME_STATE_PLAYING)
			for(var/mob/living/carbon/human/P in player_list)
				if(NO_DNA in P.species.species_traits)
					continue
				if(P.client && !(P.mind in ticker.mode.changelings) && P.mind!=owner)
					n_p++
		target_amount = min(target_amount, n_p)

	explanation_text = "Absorva [target_amount] genes compativeis."
	return target_amount

/datum/objective/absorb/check_completion()
	if(owner && owner.changeling && owner.changeling.absorbed_dna && (owner.changeling.absorbedcount >= target_amount))
		return 1
	else
		return 0

/datum/objective/destroy
	martyr_compatible = 1
	var/target_real_name

/datum/objective/destroy/find_target()
	var/list/possible_targets = active_ais(1)
	var/mob/living/silicon/ai/target_ai = pick(possible_targets)
	target = target_ai.mind
	if(target && target.current)
		target_real_name = target.current.real_name
		explanation_text = "Destrua [target_real_name], a IA."
	else
		explanation_text = "Objetivo livre"
	return target

/datum/objective/destroy/check_completion()
	if(target && target.current)
		if(target.current.stat == DEAD || is_away_level(target.current.z) || !target.current.ckey)
			return 1
		return 0
	return 1

/datum/objective/blood
/datum/objective/blood/proc/gen_amount_goal(low = 150, high = 400)
	target_amount = rand(low,high)
	target_amount = round(round(target_amount/5)*5)
	explanation_text = "Acumule pelo menos [target_amount] unidades de sangue."
	return target_amount

/datum/objective/blood/check_completion()
	if(owner && owner.vampire && owner.vampire.bloodtotal && owner.vampire.bloodtotal >= target_amount)
		return 1
	else
		return 0

// /vg/; Vox Inviolate for humans :V
/datum/objective/minimize_casualties
	explanation_text = "Diminua as casualidades."
/datum/objective/minimize_casualties/check_completion()
	if(owner.kills.len>5) return 0
	return 1

//Vox heist objectives.

/datum/objective/heist
/datum/objective/heist/proc/choose_target()
	return

/datum/objective/heist/kidnap
/datum/objective/heist/kidnap/choose_target()
	var/list/roles = list("Chief Engineer","Research Director","Roboticist","Chemist","Station Engineer")
	var/list/possible_targets = list()
	var/list/priority_targets = list()

	for(var/datum/mind/possible_target in ticker.minds)
		if(possible_target != owner && ishuman(possible_target.current) && (possible_target.current.stat != DEAD) && (possible_target.assigned_role != "MODE"))
			possible_targets += possible_target
			for(var/role in roles)
				if(possible_target.assigned_role == role)
					priority_targets += possible_target
					continue

	if(priority_targets.len > 0)
		target = pick(priority_targets)
	else if(possible_targets.len > 0)
		target = pick(possible_targets)

	if(target && target.current)
		explanation_text = "O Shoal precisa de [target.current.real_name], o [target.assigned_role]. Caputure ainda vivo."
	else
		explanation_text = "Objetivo livre"
	return target

/datum/objective/heist/kidnap/check_completion()
	if(target && target.current)
		if(target.current.stat == DEAD)
			return 0

		var/area/shuttle/vox/A = locate() //stupid fucking hardcoding
		var/area/vox_station/B = locate() //but necessary

		for(var/mob/living/carbon/human/M in A)
			if(target.current == M)
				return 1
		for(var/mob/living/carbon/human/M in B)
			if(target.current == M)
				return 1
	else
		return 0

/datum/objective/heist/loot
/datum/objective/heist/loot/choose_target()
	var/loot = "an object"
	switch(rand(1,8))
		if(1)
			target = /obj/structure/particle_accelerator
			target_amount = 6
			loot = "um acelerador de particulas inteiro"
		if(2)
			target = /obj/machinery/the_singularitygen
			target_amount = 1
			loot = "um gerador de singularidade gravitacional"
		if(3)
			target = /obj/machinery/power/emitter
			target_amount = 4
			loot = "quatro emissores"
		if(4)
			target = /obj/machinery/nuclearbomb
			target_amount = 1
			loot = "uma bomba nuclear"
		if(5)
			target = /obj/item/weapon/gun
			target_amount = 6
			loot = "seis armas, Tasers e outras armas nao leitais sao permitidas"
		if(6)
			target = /obj/item/weapon/gun/energy
			target_amount = 4
			loot = "quatro armas de ernergia"
		if(7)
			target = /obj/item/weapon/gun/energy/laser
			target_amount = 2
			loot = "duas armas laser"
		if(8)
			target = /obj/item/weapon/gun/energy/ionrifle
			target_amount = 1
			loot = "uma arma de ion"

	explanation_text = "Estamos com falta de hardwares. arranje um roubando ou trocando [loot]."

/datum/objective/heist/loot/check_completion()
	var/total_amount = 0

	for(var/obj/O in locate(/area/shuttle/vox))
		if(istype(O, target))
			total_amount++
		for(var/obj/I in O.contents)
			if(istype(I, target))
				total_amount++
			if(total_amount >= target_amount)
				return 1

	for(var/obj/O in locate(/area/vox_station))
		if(istype(O, target))
			total_amount++
		for(var/obj/I in O.contents)
			if(istype(I, target))
				total_amount++
			if(total_amount >= target_amount)
				return 1

	var/datum/game_mode/heist/H = ticker.mode
	for(var/datum/mind/raider in H.raiders)
		if(raider.current)
			for(var/obj/O in raider.current.get_contents())
				if(istype(O,target))
					total_amount++
				if(total_amount >= target_amount)
					return 1

	return 0

/datum/objective/heist/salvage
/datum/objective/heist/salvage/choose_target()
	switch(rand(1,8))
		if(1)
			target = "metal"
			target_amount = 300
		if(2)
			target = "glass"
			target_amount = 200
		if(3)
			target = "plasteel"
			target_amount = 100
		if(4)
			target = "solid plasma"
			target_amount = 100
		if(5)
			target = "silver"
			target_amount = 50
		if(6)
			target = "gold"
			target_amount = 20
		if(7)
			target = "uranium"
			target_amount = 20
		if(8)
			target = "diamond"
			target_amount = 20

	explanation_text = "Ransack or trade with the station and escape with [target_amount] [target]."

/datum/objective/heist/salvage/check_completion()
	var/total_amount = 0

	for(var/obj/item/O in locate(/area/shuttle/vox))
		var/obj/item/stack/sheet/S
		if(istype(O,/obj/item/stack/sheet))
			if(O.name == target)
				S = O
				total_amount += S.get_amount()

		for(var/obj/I in O.contents)
			if(istype(I,/obj/item/stack/sheet))
				if(I.name == target)
					S = I
					total_amount += S.get_amount()

	for(var/obj/item/O in locate(/area/vox_station))
		var/obj/item/stack/sheet/S
		if(istype(O,/obj/item/stack/sheet))
			if(O.name == target)
				S = O
				total_amount += S.get_amount()

		for(var/obj/I in O.contents)
			if(istype(I,/obj/item/stack/sheet))
				if(I.name == target)
					S = I
					total_amount += S.get_amount()

	var/datum/game_mode/heist/H = ticker.mode
	for(var/datum/mind/raider in H.raiders)
		if(raider.current)
			for(var/obj/item/O in raider.current.get_contents())
				if(istype(O,/obj/item/stack/sheet))
					if(O.name == target)
						var/obj/item/stack/sheet/S = O
						total_amount += S.get_amount()

	if(total_amount >= target_amount) return 1
	return 0


/datum/objective/heist/inviolate_crew
	explanation_text = "Nao deixe nenhum Vox para tras, mesmo que esteja morto."

/datum/objective/heist/inviolate_crew/check_completion()
	var/datum/game_mode/heist/H = ticker.mode
	if(H.is_raider_crew_safe())
		return 1
	return 0

/datum/objective/heist/inviolate_death
	explanation_text = "Siga o Inviolate. Minimize as mortes e a perda de recursos."

/datum/objective/heist/inviolate_death/check_completion()
	var/vox_allowed_kills = 3 // The number of people the vox can accidently kill. Mostly a counter to people killing themselves if a raider touches them to force fail.
	var/vox_total_kills = 0

	var/datum/game_mode/heist/H = ticker.mode
	for(var/datum/mind/raider in H.raiders)
		vox_total_kills += raider.kills.len // Kills are listed in the mind; uses this to calculate vox kills

	if(vox_total_kills > vox_allowed_kills) return 0
	return 1

// Traders

/datum/objective/trade // Yes, I know there's no check_completion. The objectives exist only to tell the traders what to get.
/datum/objective/trade/proc/choose_target(var/station)
	return

/datum/objective/trade/stock // Stock or spare parts.
	var/target_rating = 1
/datum/objective/trade/stock/choose_target(var/station)
	var/itemname
	switch(rand(1,8))
		if(1)
			target = /obj/item/weapon/stock_parts/cell
			target_amount = 10
			target_rating = 3
			itemname = "dez celulas de energia de alta capacidade"
		if(2)
			target = /obj/item/weapon/stock_parts/manipulator
			target_amount = 20
			itemname = "vinte micro manpuladores"
		if(3)
			target = /obj/item/weapon/stock_parts/matter_bin
			target_amount = 20
			itemname = "vinte matter bins"
		if(4)
			target = /obj/item/weapon/stock_parts/micro_laser
			target_amount = 15
			itemname = "quinze micro-lasers"
		if(5)
			target = /obj/item/weapon/stock_parts/capacitor
			target_amount = 15
			itemname = "quinze capacitores"
		if(6)
			target = /obj/item/weapon/stock_parts/subspace/filter
			target_amount = 4
			itemname = "quatro filtros de hiper ondas"
		if(7)
			target = /obj/item/solar_assembly
			target_amount = 10
			itemname = "dez montagens de painel solar"
		if(8)
			target = /obj/item/device/flash
			target_amount = 6
			itemname = "seis flashes"
	explanation_text = "Estamos com poucas pe�as sobressalentes. Troque por [itemname]."

//wizard

/datum/objective/wizchaos
	explanation_text = "Fa�a uma grande estraga na esta��o o m�ximo que puder. Envie a os trouxas da Nanotrasen sem varinha uma mensagem!"
	completed = 1