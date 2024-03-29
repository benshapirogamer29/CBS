/datum/game_mode
	// this includes admin-appointed traitors and multitraitors. Easy!
	var/list/datum/mind/traitors = list()
	var/list/datum/mind/implanter = list()
	var/list/datum/mind/implanted = list()

	var/datum/mind/exchange_red
	var/datum/mind/exchange_blue

/datum/game_mode/traitor
	name = "traitor"
	config_tag = "traitor"
	restricted_jobs = list("Cyborg")//They are part of the AI if he is traitor so are they, they use to get double chances
	protected_jobs = list("Security Officer", "Warden", "Detective", "Head of Security", "Captain", "Blueshield", "Nanotrasen Representative", "Security Pod Pilot", "Magistrate", "Internal Affairs Agent", "Brig Physician", "Nanotrasen Navy Officer", "Special Operations Officer")
	required_players = 0
	required_enemies = 1
	recommended_enemies = 4

	var/traitors_possible = 4 //hard limit on traitors if scaling is turned off
	var/const/traitor_scaling_coeff = 5.0 //how much does the amount of players get divided by to determine traitors


/datum/game_mode/traitor/announce()
	to_chat(world, "<B>O modo atual e Traidor!</B>")
	to_chat(world, "<B>Ha um sindicato de traidores na estacao. Nao deixe o traidor seguir com o plano!</B>")


/datum/game_mode/traitor/pre_setup()

	if(config.protect_roles_from_antagonist)
		restricted_jobs += protected_jobs

	var/list/possible_traitors = get_players_for_role(ROLE_TRAITOR)

	// stop setup if no possible traitors
	if(!possible_traitors.len)
		return 0

	var/num_traitors = 1

	if(config.traitor_scaling)
		num_traitors = max(1, round((num_players())/(traitor_scaling_coeff)))
	else
		num_traitors = max(1, min(num_players(), traitors_possible))

	for(var/j = 0, j < num_traitors, j++)
		if(!possible_traitors.len)
			break
		var/datum/mind/traitor = pick(possible_traitors)
		traitors += traitor
		traitor.special_role = SPECIAL_ROLE_TRAITOR
		var/datum/mindslaves/slaved = new()
		slaved.masters += traitor
		traitor.som = slaved //we MIGT want to mindslave someone
		traitor.restricted_roles = restricted_jobs
		possible_traitors.Remove(traitor)

	if(!traitors.len)
		return 0
	return 1


/datum/game_mode/traitor/post_setup()
	for(var/datum/mind/traitor in traitors)
		forge_traitor_objectives(traitor)
		update_traitor_icons_added(traitor)
		spawn(rand(10,100))
			finalize_traitor(traitor)
			greet_traitor(traitor)
	modePlayer += traitors
	..()

/datum/game_mode/traitor/setup_chumps()
	//since we actually have potential collaborators, we don't prepare any chumps to avoid extra people knowing our codewords.
	return

/datum/game_mode/proc/forge_traitor_objectives(datum/mind/traitor)
	if(istype(traitor.current, /mob/living/silicon))
		var/objective_count = 0

		if(prob(30))
			var/special_pick = rand(1,2)
			switch(special_pick)
				if(1)
					var/datum/objective/block/block_objective = new
					block_objective.owner = traitor
					traitor.objectives += block_objective
					objective_count++
				if(2) //Protect and strand a target
					var/datum/objective/protect/yandere_one = new
					yandere_one.owner = traitor
					traitor.objectives += yandere_one
					yandere_one.find_target()
					objective_count++
					var/datum/objective/maroon/yandere_two = new
					yandere_two.owner = traitor
					yandere_two.target = yandere_one.target
					traitor.objectives += yandere_two
					objective_count++

		for(var/i = objective_count, i < config.traitor_objectives_amount, i++)
			var/datum/objective/assassinate/kill_objective = new
			kill_objective.owner = traitor
			kill_objective.find_target()
			traitor.objectives += kill_objective

		var/datum/objective/survive/survive_objective = new
		survive_objective.owner = traitor
		traitor.objectives += survive_objective

	else
		var/is_hijacker = prob(10)
		var/martyr_chance = prob(20)
		var/objective_count = is_hijacker 			//Hijacking counts towards number of objectives
		if(!exchange_blue && traitors.len >= 8) 	//Set up an exchange if there are enough traitors
			if(!exchange_red)
				exchange_red = traitor
			else
				exchange_blue = traitor
				assign_exchange_role(exchange_red)
				assign_exchange_role(exchange_blue)
			objective_count += 1					//Exchange counts towards number of objectives
		var/list/active_ais = active_ais()
		for(var/i = objective_count, i < config.traitor_objectives_amount, i++)
			if(prob(50))
				if(active_ais.len && prob(100/player_list.len))
					var/datum/objective/destroy/destroy_objective = new
					destroy_objective.owner = traitor
					destroy_objective.find_target()
					traitor.objectives += destroy_objective
				else if(prob(5))
					var/datum/objective/debrain/debrain_objective = new
					debrain_objective.owner = traitor
					debrain_objective.find_target()
					traitor.objectives += debrain_objective
				else if(prob(30))
					var/datum/objective/maroon/maroon_objective = new
					maroon_objective.owner = traitor
					maroon_objective.find_target()
					traitor.objectives += maroon_objective
				else
					var/datum/objective/assassinate/kill_objective = new
					kill_objective.owner = traitor
					kill_objective.find_target()
					traitor.objectives += kill_objective
			else
				var/datum/objective/steal/steal_objective = new
				steal_objective.owner = traitor
				steal_objective.find_target()
				traitor.objectives += steal_objective

		if(is_hijacker && objective_count <= config.traitor_objectives_amount) //Don't assign hijack if it would exceed the number of objectives set in config.traitor_objectives_amount
			if(!(locate(/datum/objective/hijack) in traitor.objectives))
				var/datum/objective/hijack/hijack_objective = new
				hijack_objective.owner = traitor
				traitor.objectives += hijack_objective
				return


		var/martyr_compatibility = 1 //You can't succeed in stealing if you're dead.
		for(var/datum/objective/O in traitor.objectives)
			if(!O.martyr_compatible)
				martyr_compatibility = 0
				break

		if(martyr_compatibility && martyr_chance)
			var/datum/objective/die/martyr_objective = new
			martyr_objective.owner = traitor
			traitor.objectives += martyr_objective
			return

		else
			if(!(locate(/datum/objective/escape) in traitor.objectives))
				var/datum/objective/escape/escape_objective = new
				escape_objective.owner = traitor
				traitor.objectives += escape_objective
				return


/datum/game_mode/proc/greet_traitor(var/datum/mind/traitor)
	to_chat(traitor.current, "<B><font size=3 color=red>Voce e o traidor.</font></B>")
	var/obj_count = 1
	for(var/datum/objective/objective in traitor.objectives)
		to_chat(traitor.current, "<B>Objetivo #[obj_count]</B>: [objective.explanation_text]")
		obj_count++
	return


/datum/game_mode/proc/finalize_traitor(var/datum/mind/traitor)
	if(istype(traitor.current, /mob/living/silicon))
		add_law_zero(traitor.current)
	else
		equip_traitor(traitor.current)
	return


/datum/game_mode/traitor/declare_completion()
	..()
	return//Traitors will be checked as part of check_extra_completion. Leaving this here as a reminder.

/datum/game_mode/traitor/process()
	// Make sure all objectives are processed regularly, so that objectives
	// which can be checked mid-round are checked mid-round.
	for(var/datum/mind/traitor_mind in traitors)
		for(var/datum/objective/objective in traitor_mind.objectives)
			objective.check_completion()
	return 0

/datum/game_mode/proc/give_codewords(mob/living/traitor_mob)
	to_chat(traitor_mob, "<U><B>The Syndicate provided you with the following information on how to identify their agents:</B></U>")
	to_chat(traitor_mob, "<B>Code Phrase</B>: <span class='danger'>[syndicate_code_phrase]</span>")
	to_chat(traitor_mob, "<B>Code Response</B>: <span class='danger'>[syndicate_code_response]</span>")

	traitor_mob.mind.store_memory("<b>Code Phrase</b>: [syndicate_code_phrase]")
	traitor_mob.mind.store_memory("<b>Code Response</b>: [syndicate_code_response]")

	to_chat(traitor_mob, "Use the code words in the order provided, during regular conversation, to identify other agents. Proceed with caution, however, as everyone is a potential foe.")

/datum/game_mode/proc/add_law_zero(mob/living/silicon/ai/killer)
	var/law = "Cumpra o seu objetivo a qualquer custo."
	var/law_borg = "Cumpra seu objetido de IA a qualquer custo."
	to_chat(killer, "<b>Suas leis foram mudadas!</b>")
	killer.set_zeroth_law(law, law_borg)
	to_chat(killer, "Nova Lei: 0. [law]")
	give_codewords(killer)
	killer.set_syndie_radio()
	to_chat(killer, "Seu radio foi melhorado! Pressione :t para falar no canal encriptado do sindicato dos agentes!")
	killer.verbs += /mob/living/silicon/ai/proc/choose_modules
	killer.malf_picker = new /datum/module_picker


/datum/game_mode/proc/auto_declare_completion_traitor()
	if(traitors.len)
		var/text = "<FONT size = 2><B>Os traidores onde:</B></FONT>"
		for(var/datum/mind/traitor in traitors)
			var/traitorwin = 1

			text += "<br>[traitor.key] como [traitor.name] ("
			if(traitor.current)
				if(traitor.current.stat == DEAD)
					text += "morto"
				else
					text += "sobreviveu"
				if(traitor.current.real_name != traitor.name)
					text += " como [traitor.current.real_name]"
			else
				text += "corpo destruido"
			text += ")"


			var/TC_uses = 0
			var/uplink_true = 0
			var/purchases = ""
			for(var/obj/item/device/uplink/H in world_uplinks)
				if(H && H.uplink_owner && H.uplink_owner==traitor.key)
					TC_uses += H.used_TC
					uplink_true=1
					purchases += H.purchase_log

			if(uplink_true) text += " (usou [TC_uses] TC) [purchases]"


			if(traitor.objectives && traitor.objectives.len)//If the traitor had no objectives, don't need to process this.
				var/count = 1
				for(var/datum/objective/objective in traitor.objectives)
					if(objective.check_completion())
						text += "<br><B>Objetivo #[count]</B>: [objective.explanation_text] <font color='green'><B>Successo!</B></font>"
						feedback_add_details("traitor_objective","[objective.type]|SUCCESS")
					else
						text += "<br><B>Objetivo #[count]</B>: [objective.explanation_text] <font color='red'>Falhou.</font>"
						feedback_add_details("traitor_objective","[objective.type]|FAIL")
						traitorwin = 0
					count++

			var/special_role_text
			if(traitor.special_role)
				special_role_text = lowertext(traitor.special_role)
			else
				special_role_text = "antagonista"


			if(traitorwin)
				text += "<br><font color='green'><B>O [special_role_text] sucedeu!</B></font>"
				feedback_add_details("traitor_success","SUCCESS")
			else
				text += "<br><font color='red'><B>O [special_role_text] falhou!</B></font>"
				feedback_add_details("traitor_success","FAIL")


		to_chat(world, text)
	return 1


/datum/game_mode/proc/equip_traitor(mob/living/carbon/human/traitor_mob, var/safety = 0)
	if(!istype(traitor_mob))
		return
	. = 1
	if(traitor_mob.mind)
		if(traitor_mob.mind.assigned_role == "Clown")
			to_chat(traitor_mob, "Seu treino permitiu que voce superasse sua natureza de palha�o, te permitindo usar dias armassem precupa��o.")
			traitor_mob.mutations.Remove(CLUMSY)

	// find a radio! toolbox(es), backpack, belt, headset
	var/obj/item/R = locate(/obj/item/device/pda) in traitor_mob.contents //Hide the uplink in a PDA if available, otherwise radio
	if(!R)
		R = locate(/obj/item/device/radio) in traitor_mob.contents

	if(!R)
		to_chat(traitor_mob, "Infelizmente, o sindicato n�o conseguiu receber o seu r�dio.")
		. = 0
	else
		if(istype(R, /obj/item/device/radio))
			// generate list of radio freqs
			var/obj/item/device/radio/target_radio = R
			var/freq = PUBLIC_LOW_FREQ
			var/list/freqlist = list()
			while(freq <= PUBLIC_HIGH_FREQ)
				if(freq < 1451 || freq > 1459)
					freqlist += freq
				freq += 2
				if((freq % 2) == 0)
					freq += 1
			freq = freqlist[rand(1, freqlist.len)]

			var/obj/item/device/uplink/hidden/T = new(R)
			target_radio.hidden_uplink = T
			T.uplink_owner = "[traitor_mob.key]"
			target_radio.traitor_frequency = freq
			to_chat(traitor_mob, "O sindicato disfar�ou astutamente um link de sindicato como seu [R.name] [T.loc]. Discador de frequencia simples [format_frequency(freq)] para desbloquear seus recursos ocultos.")
			traitor_mob.mind.store_memory("<B>Radio Freq:</B> [format_frequency(freq)] ([R.name] [T.loc]).")
		else if(istype(R, /obj/item/device/pda))
			// generate a passcode if the uplink is hidden in a PDA
			var/pda_pass = "[rand(100,999)] [pick("Alpha","Bravo","Delta","Omega")]"

			var/obj/item/device/uplink/hidden/T = new(R)
			R.hidden_uplink = T
			T.uplink_owner = "[traitor_mob.key]"
			var/obj/item/device/pda/P = R
			P.lock_code = pda_pass

			to_chat(traitor_mob, "O sindicato disfar�ou astutamente um link de sindicato como seu [R.name] [T.loc]. Discador de frequencia simples \"[pda_pass]\" no toque selecione para desbloquear seus recursos ocultos.")
			traitor_mob.mind.store_memory("<B>Uplink Passcode:</B> [pda_pass] ([R.name] [T.loc]).")
	if(!safety)//If they are not a rev. Can be added on to.
		give_codewords(traitor_mob)

	// Tell them about people they might want to contact.
	var/mob/living/carbon/human/M = get_nt_opposed()
	if(M && M != traitor_mob)
		to_chat(traitor_mob, "Nos recebemos informacoes confiaveis de [M.real_name] talvez ele possa nos ajudar na nossa causa. Se voce precisar de ajuda, considere contacta-lo.")
		traitor_mob.mind.store_memory("<b>Potential Collaborator</b>: [M.real_name]")
		//let's also inform their contact that they might be called upon, but leave it vague.
		inform_collab(M)

/datum/game_mode/traitor/inform_collab(mob/living/carbon/human/M)
	if(M.mind in traitors)		//if you are already a traitor, you already know the codewords and your role, so skip this message.
		return
	..(M)


/datum/game_mode/proc/remove_traitor(datum/mind/traitor_mind)
	if(traitor_mind in traitors)
		ticker.mode.traitors -= traitor_mind
		traitor_mind.special_role = null
		traitor_mind.current.create_attack_log("<span class='danger'>De-traitored</span>")
		if(issilicon(traitor_mind.current))
			to_chat(traitor_mind.current, "<span class='userdanger'>Voce agora foi transformado em robo! Voce deixou de ser um traidor.</span>")
		else
			to_chat(traitor_mind.current, "<span class='userdanger'>Voce sofreu lavagem cerebral! Voce nao e mais um traidor.</span>")
		ticker.mode.update_traitor_icons_removed(traitor_mind)

/datum/game_mode/proc/update_traitor_icons_added(datum/mind/traitor_mind)
	var/datum/atom_hud/antag/tatorhud = huds[ANTAG_HUD_TRAITOR]
	tatorhud.join_hud(traitor_mind.current)
	set_antag_hud(traitor_mind.current, "hudsyndicate")

/datum/game_mode/proc/update_traitor_icons_removed(datum/mind/traitor_mind)
	var/datum/atom_hud/antag/tatorhud = huds[ANTAG_HUD_TRAITOR]
	tatorhud.leave_hud(traitor_mind.current)
	set_antag_hud(traitor_mind.current, null)


/datum/game_mode/proc/remove_traitor_mind(datum/mind/traitor_mind, datum/mind/head)
	if(traitor_mind in implanted)
		//var/list/removal
		var/ref = "\ref[head]"
		if(ref in implanter)
			implanter[ref] -= traitor_mind
		implanted -= traitor_mind
		traitors -= traitor_mind
		if(traitor_mind.som)
			var/datum/mindslaves/slaved = traitor_mind.som
			slaved.serv -= traitor_mind
			traitor_mind.special_role = null
			traitor_mind.som = null
			slaved.leave_serv_hud(traitor_mind)
			for(var/datum/objective/protect/mindslave/MS in traitor_mind.objectives)
				traitor_mind.objectives -= MS

		update_traitor_icons_removed(traitor_mind)
		if(issilicon(traitor_mind.current))
			to_chat(traitor_mind.current, "<span class='userdanger'>Voce foi transformado em robo! Voce nao e mais um escravo mental.</span>")
		else
			to_chat(traitor_mind.current, "<span class='userdanger'>Voce nao e mais um escravo mental: agora voce tem total controle das suas faculdades mentais, mais uma vez!</span>")

/datum/game_mode/proc/assign_exchange_role(var/datum/mind/owner)
	//set faction
	var/faction = "red"
	if(owner == exchange_blue)
		faction = "blue"

	//Assign objectives
	var/datum/objective/steal/exchange/exchange_objective = new
	exchange_objective.set_faction(faction,((faction == "red") ? exchange_blue : exchange_red))
	exchange_objective.owner = owner
	owner.objectives += exchange_objective

	if(prob(20))
		var/datum/objective/steal/exchange/backstab/backstab_objective = new
		backstab_objective.set_faction(faction)
		backstab_objective.owner = owner
		owner.objectives += backstab_objective

	//Spawn and equip documents
	var/mob/living/carbon/human/mob = owner.current

	var/obj/item/weapon/folder/syndicate/folder
	if(owner == exchange_red)
		folder = new/obj/item/weapon/folder/syndicate/red(mob.locs)
	else
		folder = new/obj/item/weapon/folder/syndicate/blue(mob.locs)

	var/list/slots = list (
		"backpack" = slot_in_backpack,
		"left pocket" = slot_l_store,
		"right pocket" = slot_r_store,
		"left hand" = slot_l_hand,
		"right hand" = slot_r_hand,
	)

	var/where = "At your feet"
	var/equipped_slot = mob.equip_in_one_of_slots(folder, slots)
	if(equipped_slot)
		where = "In your [equipped_slot]"
	to_chat(mob, "<BR><BR><span class='info'>[where] e uma pasta contendo <b>documentos secretos</b> isto e o que o Sindicato quer que voce faca. Nos precisamos nos encontrar com um dos agentes na estacao para fazer a troca. Tenha extremo cuidado, pois n�o podem ser confi�veis e podem ser hostis.</span><BR>")
	mob.update_icons()
