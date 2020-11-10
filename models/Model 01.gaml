/***
* Name: Model01
* Author: kevin
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Model01

/**********************************************ENVIRONMENT***************************************************** */
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
	float max_speed <- 10 #km/#h;
	
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
			  * other hobbies places
			  *  set default type, already predefine in our hobbies_list
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
		}
		
		/*create infected people */
		ask nb_people_infected among (people){
			is_infected <- true;
			//write color;
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

species people skills: [moving] control:fsm {
	float speed;
	int age <- (10+rnd(90));
	bool is_infected <- false;
	rgb color;
	building building_work ;
	building building_living;
	building building_eating;
	building building_hobby;
	building building_school;
	building building_hospital;
	building building_goal; 
	place living_zone;
	point goal <- nil;
	
	point tmp <- nil;
	int begin_activity;
	int end_activity;

	 /*
	  * @reflex move to activies  work or school or hobby
	  */
	  
	reflex runActivity when: current_date.hour = begin_activity{
		if any_location_in(building_school) != nil{
			goal <- any_location_in(building_work);
		}else if any_location_in(building_work) != nil{
			goal <- any_location_in(building_work);
		}else if any_location_in(building_hobby) != nil{
			goal <- any_location_in(building_hobby);
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
		goal <- building_eating.location;
	}

	  
	/*
	 *@people should move on graph to thier goal specially when different nil.
	 *@goal may be nil when people will reach his goal. 
	 */
	reflex moveToBuilding when: goal != nil {
		
		do goto target:goal on: roads_topology;
		
		if location = goal {
			if goal = any_location_in(building_work) or goal = any_location_in(building_school) or goal = any_location_in(building_hospital){
				tmp <- goal;
			}
			goal <- nil;
		}	
	}
	
	/*
	 *@goal is nil, people stays inside building and he can move regarding some probability to move
	 */
	reflex stayInBuilding when: (goal = nil) and (begin_activity  < current_date.hour) and (current_date.hour < max_activity_end)  {
		
		if flip(move_probability) and (color != #black) {
			
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
	 }
	
	
	aspect basic{
		color <- (not(is_infected))? #cyan:((flip(contract_disease_probability))?(#violet):((flip(80)? #red: #black)));
		draw sphere(5) at: {location.x,location.y,location.z + 3} color: color ;
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
	aspect basic{
		draw shape color:color;
	} 
}

/***********************************************EXPERIMENT********************************************************/
experiment Model01 type: gui {
	/** Insert here the definition of the input and output of the model */
	parameter "Number of people" var: nb_people min:1000 max:10000 category: "People";
	parameter "Number of infected people" var: nb_people_infected min:0 max:5000 category: "People";
	parameter "Minimal Speed" var: min_speed min:2 max:5 category: "People";
	parameter "Maximal Speed" var: max_speed min:5 max:10 category: "People";
	parameter "Minimal Hours to start activities" var: min_activity_start  min:6 max:9 category: "People";
	parameter "Maximal Hours to start activities" var: max_activity_start  min:9 max:12 category: "People";
	parameter "Minimal Hours to end activies" var: min_activity_end  min:15 max:17 category: "People";
	parameter "Maximal Hours to end activies" var: max_activity_end  min:17 max:24 category: "People";
	parameter "Avoid at distance" var: distance_neighbors min:2 max:10 category: "People";
	output {
		display simulation_disease type:opengl {
			species road aspect:basic;
			species building aspect:basic;
			species place aspect:basic;
			species people aspect:basic;
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
		monitor "people infected" value: people count(each.is_infected) color:#red;
		monitor "people died among the infected" value: people count(each.color=#black) color:#red;

	}
}
