/***
* Name: Model02
* Author: kevin
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Model02

/*@Adding in this model :
 * 
 * @goTobuilding_hospital is a reflex, people should go to the building_hospital when they contract virus.
 * @doctor species, to take care of sick people
 * @building_hospital species , let assume  that all building_hospitals which are part of building, figth against disease and they can communicate.
 * @Initialize disease in particular part of town.
 * @Set the zone in quarantine by a particular case infected number
 * 
 */

global {
	/** Insert the global definitions, variables and actions here */
	float step <- 10 #mn;
	int nb_people <- 1000;
	int nb_people_infected <- 100;
	float move_probability <- 0.05;
	int distance_neighbors <- 2 #m;
	float contract_disease_probability <- 0.3;
	date starting_date <- date("2020-01-01-00-00-00");
	int min_activity_start <- 6;
	int max_activity_start  <- 8;
	int min_activity_end <- 17;
	int max_activity_end  <- 21;
	float min_speed <- 2 #km/#h;
	float max_speed <- 5 #km/#h;
	/*@Adding */
	int threshold_for_quarantine <- 200;
	int nb_doctors <- 2;
	/*
	 * import GIS shapefile
	 */
	file roads_shape_file <- file("../includes/roads.shp");
	file buildings_shape_file <- file("../includes/buildings.shp");
	file places_shape_file <- file("../includes/places.shp");
	geometry shape <- envelope(envelope(roads_shape_file) + envelope(buildings_shape_file) + envelope(places_shape_file));
	
	
	/*
	 * @graph using to get road topology
	 * we use it to make sure people move on the road by handle shortest path
	 */
	graph roads_topology;
	
	
	/*
	 *@here definition differents type of buildings in our shapefile
	 */
	list works_list <- ["industrial","warehouse","construction","office","electricity","embassy","power","government","manufacture","garage","garages","hangar"];
	list schools_list <-  ["university", "school" ];
	list commercials_list <- ["commercial","retail","supermarket","kiosk","mall","parking","shed","silo"];
	list residences_list <- ["apartments", "house", "hotel","residential","greenhouse","hut","semidetached_house","shelter","home"];
	list hobbies_list <- ["civic","church","service","cinema","kindergarten","public","hall","latrine","religious","sports_hall","sports_centre"];
	list hospitals_list <- ["hospital","clinic"];
	list some_places_list  <- ["kev","kev1","kev2","kev3","HansaViertel"];
	init{		
		create road from:roads_shape_file;
		/*
		 * @each road look as edges
		 */
		roads_topology<- as_edge_graph(road);
		
		create place from: places_shape_file with: [name_place::string(read('name'))];
		
		create building from: buildings_shape_file with: [type_building::string(read('type')), name_building::string(read('name'))] {
			/*
			 * gray color represent others building
			 */
			switch type_building{
				match_one (works_list) {color <- #blue; }
				match_one (schools_list) {color <- #yellow; } 
				match_one  (commercials_list)  {color <- #olive; } 
				match_one (residences_list) {color <- #brown; } 
				match_one (hobbies_list) {color <- #orange;} 
				match_one (hospitals_list)  {color <- #green; }
			}
			/*
			 *  building represent type nil and name nil, are living place
			 *  set default type, already predefine in our residences_list
			 */
			 
			 if type_building = "" and name_building = ""{
			 	
			 	type_building <- "home";
			 	color <- #brown;
			 }
			 /*
			  * other hospitals places
			  */
			  
			 if type_building = "" and name_building != ""{
			 	
			 	type_building <- "clinic";
			 	color <- #green;
			 }
			 
		}
		
		/*
		 * @create people, set her building_living and her work_living, and initialize location at living, eating and hobby places
		 */
		create people number: nb_people{
			speed <- rnd(min_speed,max_speed);
			begin_activity <- rnd(min_activity_start,max_activity_start);
			end_activity <- rnd(min_activity_end, max_activity_end);
			building_living <- one_of(building where  (residences_list contains each.type_building) );
			living_zone <- one_of(place where  (some_places_list contains each.name_place) );
			/*initial people still at home */
			location <- any_location_in(building_living);
			if age < 20 {
				building_school <- one_of(building where  (schools_list contains each.type_building) );
			}else if age < 60 {
				building_work <- one_of(building where  (works_list contains each.type_building) );
			} 
			
			building_eating <- one_of(building where  (commercials_list contains each.type_building) );
			building_hobby <- one_of(building where  (hobbies_list contains each.type_building) );
			building_hospital <- one_of(building where  (hospitals_list contains each.type_building) );
			//write any_location_in(building_hospital);
		}
		
		/*create infected people */
		ask nb_people_infected among people where (each.living_zone.name_place = "kev" ) {
	       self.is_infected <- true;
		}
		
		ask  building where (each.color = #green){
			
			create hospital {
				self.location <- myself.location;
				self.color  <- myself.color;
				self.type_building  <- myself.type_building;
				self.name_building  <- myself.name_building;
			} 
				
			}
		/* put same nb_doctors doctors inside each hospital */
		ask target:  list(hospital) {
			create doctor number:nb_doctors{
				age <- (25+rnd(35));
				is_infected <- false;
				building_work <- myself;
				building_hospital <- myself;
				location  <- any_location_in(building_work);
				int begin_activity <- current_date.hour;
				int end_activity <-24 ;
			}
		}
		
	}

}

/*****************************************************SPECIES******************************************************** */

/*
 * @species people with moving skills, they move to building
 * @speed represnt people's speeds, they move with a constant speed.
 * @building_work people workplace 
 * @building_living people living place
 * @goal defines people target which is building position
 * @is_infected represent people health state, false for healthy and true for sick. Initialize at false
 */

species people skills: [moving] {
	float speed;
	int age <- (1+rnd(95));
	bool is_infected <- false;
	rgb color;
	building building_work ;
	building building_living;
	building building_eating;
	building building_hobby;
	building building_school;
	building building_hospital;
	building building_goal ; 
	place living_zone;
	point goal <- nil;
	
	point tmp <- nil;
	int begin_activity  ;
	int end_activity;

	 /*
	  * @reflex move to activies  work or school or hobby
	  */
	  
	reflex runActivity when: current_date.hour = begin_activity{
		if is_infected and color != #black {
			building_goal <- building_hospital;
	 		goal <- any_location_in(building_goal);
		}else{
			if any_location_in(building_school) != nil{
				goal <- any_location_in(building_work);
			}else if any_location_in(building_work) != nil{
				goal <- any_location_in(building_work);
			}else if any_location_in(building_hobby) != nil{
				goal <- any_location_in(building_hobby);
			}
		
		}
		
	}
	
	/*
	 * @return at home
	 */
	 reflex backHome  when: (current_date.hour = end_activity) or (current_date.hour < max_activity_end) {
	 	if flip(0.05) and color!=#black{
	 		goal <- any_location_in(building_living);
	 	}else if(current_date.hour = max_activity_end and color!=#black){
	 		goal <- any_location_in(building_living);
	 	}
	 	
	 }
	 
	 /*
	  * @reflex move to eat, goal must set and goal prvious must save
	  */
	reflex breakToEat when: current_date.hour = (int((begin_activity + end_activity)/2)){
		tmp <- goal;
		goal <- any_location_in(building_eating);
	}

	  
	/*
	 *@people should move on graph to thier goal specially when different nil.
	 *@goal may be nil when people will reach his goal. 
	 */
	reflex moveToBuilding when: goal != nil {
		
		do goto target:goal on: roads_topology;
		
		if location = goal {
			/*save position in tmp */
			if goal = any_location_in(building_work) or goal = any_location_in(building_school) or goal = any_location_in(building_hospital){
				tmp <- goal;
			}
			goal <- nil;
		}	
	}
	
	/*
	 *@goal is nil, people stays inside building and he can move regarding some probability to move
	 */
	reflex stayInBuilding when: (goal = nil) and (begin_activity  < current_date.hour) and (current_date.hour < max_activity_end){
		
		if flip(move_probability) and (color != #black) {
			/*@other condition to move */
			
			if living_zone.color != #red{
			
				switch tmp {
					match (any_location_in(building_eating)){ goal <- tmp; }
					match_one [any_location_in(building_work),any_location_in(building_school)]{ if current_date.hour = end_activity {
														building_goal <- one_of(building);
														goal  <- any_location_in(building_goal);
													}else{goal <- nil;}}
					match_one [any_location_in(building_hospital)]{ if is_infected {
															goal <- nil; //always stay at hospital
													}else{
														building_goal <- one_of(building);
														goal  <- any_location_in(building_goal);
													}}
					default { building_goal <- one_of(building); goal <- any_location_in(building_goal); }
				}
				
			}else{
				if tmp = any_location_in(building_living){
					goal <- nil;
				}else{
					/*@people must leave to house */
					building_goal <- building_living;
					goal <- any_location_in(building_goal);
				}
				
			}
	
		}
	}
	
	/*
	 * @spreading disease
	 */
	 
	 reflex spreadingDisease when: (is_infected and color!=#black){
	 	ask people at_distance(distance_neighbors) where (each.color = #cyan){
			if age < 30{
	 			if flip(contract_disease_probability){
		 				 is_infected <- true;
		 			}
		 	}else if age < 70{
		 			if flip(1 - contract_disease_probability){
		 				is_infected <- true;
		 			}
		 	}else{
		 			is_infected <- true;
		 	}
		}
		 /*@move to hospital when sick */
		building_goal <- building_hospital;
	 	goal <- any_location_in(building_goal);
	 }
	
	
	aspect basic{
		color <- (not(is_infected))? #cyan:((flip(contract_disease_probability))?(#violet):((flip(80)? #red: #black)));
		draw sphere(5) at: {location.x,location.y,location.z + 3} color: color ;
	}
}

/*@doctor species */
species doctor parent: people {
	
	list<place> quarantine_zone;
	
	reflex runActivity when: current_date.hour = begin_activity{self.goal <- nil; } // doctor still at work
	
	reflex stayInBuilding when: (goal = nil){}
	
	reflex backHome  when: (current_date.hour = end_activity){self.goal <- nil;} 
	
	reflex breakToEat when: current_date.hour = (int((self.begin_activity + self.end_activity)/2)){self.goal <- nil;}
	
	reflex cure when: self.goal = nil {
		ask people inside self.building_hospital where (each.is_infected and each.color != #black){
			
				if self.color = #violet{
				   if flip(0.80){
				   		self.color <- #cyan;
				   }else{
				   		if flip(0.2){
				   			self.color <- #red;
				   		}
				   }
				}else{
				   if flip(0.60){
				   	 self.color <- #violet;
				   }else{
				   	
				   	 if flip(0.2){
				   	 	 self.color <- #black;
				   	 }
				   	
				   }
				}
		}
	
	}
	
	reflex quarantine when: flip(0.5){
		place target_place <- one_of(place);
		list<people> infected_list <- (people inside target_place  where each.is_infected);
		if (length(infected_list) > threshold_for_quarantine ){
			target_place.color <- #red;
			 add target_place to:quarantine_zone ;
			goal  <- any_location_in(target_place);
		}
	}
	
	reflex cure_in_zone when: (quarantine_zone!=nil) {
		ask people inside one_of(quarantine_zone) where  (each.is_infected and each.color != #black){
			
				if color = #violet{
				   if flip(0.80){
				   		self.color <- #cyan;
				   }else{
				   		if flip(0.2){
				   			self.color <- #red;
				   		}
				   }
				}else{
				   if flip(0.60){
				   	 self.color <- #violet;
				   }else{
					   	if flip(0.2){
					   			self.color <- #red;
					   	}
				   }
				}
		}
		place target <- one_of(quarantine_zone);
		if length(people inside target  where each.is_infected) < threshold_for_quarantine{
			//doctor return to hospital to cure others
			goal <- any_location_in(self.building_hospital); 
			remove target from: quarantine_zone;
		}
	}
	
	aspect basic {
		draw sphere(5) at: {location.x,location.y,location.z + 3}  color:#white;
	}
}

species hospital parent:building {
	list<hospital> Hospitals <- [] update: (building where (hospitals_list contains each.type_building));
	
	string message_send;
	
	reflex communicate  when: flip(0.5) {
		ask target:list(Hospitals){
			myself.message_send <- "fight in progress"; 
		}
	}
	
	reflex received_infos  when: message_send != nil {
		ask target:list(Hospitals){
			self.message_send <- "well received, go ahead!"; 
		}
	}
}


/*
 * @species road
 */
 
species road {
	geometry display_shape <- shape + 2.0;
	aspect basic{
		draw display_shape color:#black depth:3.0;
	}
}
/*
 * @species building
 * @type define building type
 * @color repesent bulding color to differenciate them
 * @name_building
 */
 
species building{
	string type_building;
	string name_building;
	rgb color <- #gray;
	float height <- rnd(10#m, 20#m) ;
	aspect basic{
		draw shape color: color  border: #black depth: height;
	} 
}

species place{
	string name_place;
	rgb color <- #transparent;
	bool is_quarantine <- false;
	aspect basic{
		draw shape color:color;
	} 
}



/***********************************************EXPERIMENT********************************************************/
experiment Model02 type: gui {
	/** Insert here the definition of the input and output of the model */
	parameter "Number of people" var: nb_people min:1000 max:10000 category: "People";
	parameter "Number of infected people" var: nb_people_infected min:0 max:5000 category: "People";
	parameter "Minimal Speed" var: min_speed min:1 max:2 category: "People";
	parameter "Maximal Speed" var: max_speed min:2 max:5 category: "People";
	parameter "Minimal Hours to start activities" var: min_activity_start  min:6 max:9 category: "People";
	parameter "Maximal Hours to start activities" var: max_activity_start  min:9 max:12 category: "People";
	parameter "Minimal Hours to end activies" var: min_activity_end  min:15 max:17 category: "People";
	parameter "Maximal Hours to end activies" var: max_activity_end  min:17 max:24 category: "People";
	parameter "Avoid at distance" var: distance_neighbors min:2 max:10 category: "People";
	output {
		display simulation_disease type: opengl  {
			species road aspect:basic;
			species building aspect:basic;
			species place aspect:basic;
			species people aspect:basic;
			species doctor aspect:basic;
			species hospital aspect:basic;
			
		}
		
		display peopleDistribution{
			
			chart "people with age distribution" type: histogram{
				data "age least than 20" value: people count( each.age <= 20 ) color:#red;
				data "age between 19 and 40" value: people count( 20 < each.age and each.age < 40 ) color:#blue;
				data "age between 40 and 60" value: people count( 40 < each.age and each.age <= 60 )  color:#blue;
				data "age between 60 and 80" value: people count( 40 < each.age and each.age <= 80 ) color:#blue;
				data "age over 80"   value: people count( 80 < each.age and each.age <= 100 ) color:#blue;
			}
		}
		
		
		/*add monitor */ 
		monitor "Calender" value: current_date  color:#pink;
		monitor "people not infected" value: people count(not(each.is_infected)) color:#green;
		monitor "people infected" value: people count(each.is_infected) color:#red ;
		
	}
}
