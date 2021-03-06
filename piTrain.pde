import processing.serial.*;

Serial rs485;	
Serial handController;
Serial dccCentral;

/* next things to do
    * train controller 
    * SSP 
    * make route determenation (detect links between parts)
    * make special crossing part for 4 servo's N.B propably not needed if switches can share the same ID
    * perhaps make rs485 interface in order to initialize the arduino boards. Terminal, highly recommendable to do so
    * make a stop section to mark end of track
    * fix switch's graphics remove black line and move white line
    * be able to remove (set ID to 0) or modify the state of a switch in a memory
    * when mode = NAME display ID when new item is selected
    * make buttons class for alternative items
*/
    
    
    
int gridSize;
int caseSelector = 0, caseSelector_prev=1;
boolean locked = false;

String line;

boolean memorySelected = false;
boolean menu_bool = false;

final int	idle = 1;
final int 	signalInstruction = 1;
final int	decouplerInstruction = 2;
final int	turnoutInstruction = 3;
final int	detectorInstruction = 4;
final int	memoryInstruction = 5;

final int play = 0;
final int settingID = 1;
final int addingSwitch = 2;
final int movingItem = 3;
final int deletingItem = 4;
final int settingName = 5;
final int addingSignal = 6;
final int IDLE = 255;

int mode = movingItem;
int Mode = idle;

PrintWriter output;
BufferedReader input;

int left = 1;
int right = 2;

int signalID;
int switchID;
int state;

int item;

int index;
int selector;

int row;
int column;

int ID;

int edgeOffset = 23;

boolean assignID_bool = false;
int number = 0;

long handControllerTimeout;
boolean handControllerConnected = false;

Switch sw1;
Switch sw2;
Line l1;
Curve c1;
Detection d1;
Memory m1;
Decoupler D1;
Signal S1;

//SSP ssp1;
Display display;
boolean debug = true ;

ArrayList <RailItem> railItems = new ArrayList();


void setup() {
    
  
    int dcc_index = 0, rs485_index = 0;
    display = new Display(5, 5, 1014, 374);
    textAlign(CENTER,CENTER);
    textSize(8);
    gridSize = 35;
    gridSize = constrain(gridSize, 10, 50);
    size(1600,600);
    background(255);
    //fullScreen();

    sw1 = new Switch(	0,	(width-gridSize-edgeOffset) / gridSize, 0, 2, 1, gridSize, 1); // make default Objects to display on the right side of the UI
    sw2 = new Switch(	0,	(width-gridSize-edgeOffset) / gridSize, 1, 2, 2, gridSize, 1);
    l1 =  new Line(			(width-gridSize-edgeOffset) / gridSize, 2, 2,    gridSize);
    c1 =  new Curve(		(width-gridSize-edgeOffset) / gridSize, 3, 2,    gridSize);
    d1 =  new Detection(0,	(width-gridSize-edgeOffset) / gridSize, 4, 2,    gridSize);
    m1 =  new Memory(	0,	(width-gridSize-edgeOffset) / gridSize, 5, 2,    gridSize);
    D1 =  new Decoupler(0,	(width-gridSize-edgeOffset) / gridSize, 6, 2,    gridSize);
    S1 =  new Signal(   0,  (width-gridSize-edgeOffset) / gridSize, 7, 0,    gridSize, 0);
//ssp1 = new SSP("ssp1.txt");
    
    loadLayout();
    if( !debug ) {
    //printArray(Serial.list());

      for( byte i = 0; i < Serial.list().length; i++) { // WORKS 
          println(i + " " + Serial.list()[i]);
  
          if( Serial.list()[i].charAt(8) == 'U' ) {
              dcc_index = i;
              rs485_index = i + 1;
              break;
          }
      }
      println("setting up connecton with DCC central");
      dccCentral = new Serial(this, Serial.list()[dcc_index], 115200);
      
      
      while( dccCentral.available() < 5 ) {
          int ammount = dccCentral.available();
          delay(1);
          if( ammount  >= 5) break;
          if(millis() > 10000 ) {
              println("timeout occured");
              break;
          }
      }
      println(dccCentral.available());
      String respons = "";
      for( int i = 0 ; i < 5 ; i ++ ) {
          respons += (char)dccCentral.read();
      }
      println("respons = " + respons);
      if( respons.charAt(0) == 'h' 
      &&  respons.charAt(1) == 'e' 
      &&  respons.charAt(2) == 'l' 
      &&  respons.charAt(3) == 'l' 
      &&  respons.charAt(4) == 'o' ) 
      { 
          println("respons confirmed, connection with DCC central established");
      }
      else {
          rs485_index--; // swap USB ports in the event of failed communication
          dcc_index++;
          dccCentral.stop();
          dccCentral = new Serial(this, Serial.list()[dcc_index], 115200);
      }
      println("setting up connecton with RS485 bus");
      rs485           = new Serial(this, Serial.list()[rs485_index], 115200);
      println("connecton set up!");
      
      
  
      handController = new Serial( this , "/dev/rfcomm0" , 9600 );
      handControllerConnected = true;
  
      //println("connecton started");
      //handController.write("$$9");
      //dccCentral.write("g0");
  
      //delay(3000);
      while(rs485.available() > 0) rs485.read();
      resetBus();
      handControllerTimeout = millis() + 5000 ;
  }
} 

void handShaking() {
    int b;

    if( handController.available() > 0 ) {
        if( handControllerConnected == false ) {
            handControllerConnected = true;
            println("connection with handcontroller established!");
        }

        b = handController.read();
        dccCentral.write( b );
        println("controller: " + (char) b );

        handControllerTimeout = millis() + 5000 ;
    }

    if(dccCentral.available() > 0 ) {
        b = dccCentral.read();
        handController.write( b );
        println("central: " + (char) b );
    }

    if( millis() > handControllerTimeout ) {

        if( handControllerConnected == true ) {
            handControllerConnected = false;
            println("connection with hand controller lost!");
            handControllerTimeout = millis() + 5000 ;
        }
        else {
            try {
                handController.stop();
            }
            catch ( NullPointerException  e) {
                println(" error terminating connection ");
            }
            try {
                handController = new Serial( this , "/dev/rfcomm0" , 9600 );
                handController.write('$');
                handController.write('$');
                handController.write('9');
                println("attempting to connect with hand controller...");
            } 
            catch(Exception e){
                println("error cannot set up hand controller connection");
            }
            handControllerTimeout = millis() + 10000 ;
        }
    }
}

void draw() {

    if( !debug) {
        handShaking();
        readSerialBus();
    }

    //ssp1.runCommands();
    fill(255);

    stroke(255);
    rect(0,0,width,height); // clear screen 
    stroke(0);
    
    column = (gridSize/2+constrain(mouseX,0,width-2*gridSize)) / gridSize - 1;
    row = (gridSize/2+constrain(mouseY,0,height-2*gridSize)) / gridSize - 1;
    
    drawGrid();						// draw items on the right
    sw1.Draw();
    sw2.Draw();
    l1.Draw();
    c1.Draw();
    d1.Draw();
    m1.Draw();
    D1.Draw();
    S1.Draw();
    
    for (int i = 0; i < railItems.size(); i++) {	
        RailItem anyClass = railItems.get(i);
        if(anyClass instanceof Switch) 	  { Switch sw = (Switch) anyClass; sw.Draw();}
        if(anyClass instanceof Detection) { Detection det = (Detection) anyClass; det.Draw();}
        if(anyClass instanceof Line) 	  { Line ln = (Line) anyClass; ln.Draw();}
        if(anyClass instanceof Curve) 	  { Curve cv = (Curve) anyClass; cv.Draw();}
        if(anyClass instanceof Memory) 	  { Memory mem = (Memory) anyClass; mem.Draw();}
        if(anyClass instanceof Decoupler) { Decoupler dec = (Decoupler) anyClass; dec.Draw();}
        if(anyClass instanceof Signal) 	  { Signal sig = (Signal) anyClass; sig.Draw();} }
    
    fill(0);
    textSize(gridSize / 4);
    text("SAVE",gridSize/2, height - gridSize/2);

//display.paint();
}

void drawGrid() {
    if(mode != play){
        for(int i=0;i<((width-2*gridSize)/gridSize);i++){
            for(int j=0;j<((height-2*gridSize)/gridSize);j++){
                rect(gridSize+i*gridSize,gridSize+j*gridSize,1,1);} } } }

void resetBus() {
    Mode = idle;
    caseSelector = 0;
    println("rs485 bus cleared");
}

void readSerialBus() {
    if(rs485.available() > 0) {
        int b = rs485.read();
        println(b);
        
        switch(Mode) {
            case idle: Mode = b; break;
            case memoryInstruction:	  	if(memoryInstructionF(b)) 		resetBus(); break;
            case decouplerInstruction:	if(decouplerInstructionF(b))	resetBus(); break;
            case detectorInstruction:	if(detectorInstructionF(b)) 	resetBus(); break;
        }
    }
}

boolean memoryInstructionF(int b) {
    switch(caseSelector++) {
        case 0: // memory ID
        ID = b;
        //print("memory " + ID + "activated");
        break;
        
        case 1: // memory state
        for (int i = 0; i < railItems.size(); i++) { 
            RailItem anyClass = railItems.get(i);                                 
            if((anyClass instanceof Memory)) {
                if(anyClass.getID() == ID) {
                    //println("memory ID = " + ID);
                    clearMemoryStates();
                    anyClass.setState(1);
                    setSwitches(anyClass);
                    return true; } } }
        return true; }
    return false; }

boolean decouplerInstructionF(int b) {
    switch(caseSelector++) {
        case 0: // decoupler ID
        print("decoupler " + ID + "activated");
        ID = b;
        break;
        
        case 1: // decoupler state
        for (int i = 0; i < railItems.size(); i++) { 
            RailItem anyClass = railItems.get(i);																		 
            if(anyClass instanceof Decoupler){
                if(anyClass.getID() == ID) {
                    if(b == 1)	anyClass.setState(1);
                    else		anyClass.setState(0); } } }
        return true; }
    return false; }

boolean detectorInstructionF(int b) {
    switch(caseSelector++) {
        case 0: // detector ID
        ID = b;
        break;
        
        case 1: // detector state
        for (int i = 0; i < railItems.size(); i++) { 
            RailItem anyClass = railItems.get(i);																 
            if((anyClass instanceof Detection)) {
                if(anyClass.getID() == ID) {
                    anyClass.setState(b); 
                    if( b > 0 ) setSignals(anyClass);
                    return true; } } }
        return true; }
    return false; }

void clearMemoryStates() {
    for (int i = 0; i < railItems.size(); i++) { 
        RailItem anyClass = railItems.get(i);																		 
        if(anyClass instanceof Memory) {
            anyClass.setState(0); } } }

void mousePressed()
{	
    if(mouseX < width / 2 && mouseY > height - gridSize) saveLayout(); // works
    //if(mouseX > width / 2 && mouseY > height - gridSize) loadLayout(); // WORK IN PROGRESS
    RailItem anyClass = railItems.get(0);
    
    for (int i = 0; i < railItems.size(); i++) { 
        anyClass = railItems.get(i);																			// store the object in 'anyClass' 
        if(column == anyClass.getColumn() && row == anyClass.getRow()) {	// get index of clicked item	 
            locked = true;
            index = i;
            if(anyClass instanceof Switch) 		print("SWITCH ");
            if(anyClass instanceof Line)	 	print("LINE ");
            if(anyClass instanceof Curve) 		print("CURVE ");
            if(anyClass instanceof Memory) 		print("MEMORY ");
            if(anyClass instanceof Detection) 	print("DETECTOR ");
            if(anyClass instanceof Detection) 	print("DECOUPLER ");
            if(anyClass instanceof Signal) 		print("SIGNAL ");
            println("SELECTED");
            break;
        } 
    }
    
    switch(mode) { 
        case play:
        if( anyClass instanceof Signal) {
            println("SIGNAL ACTIVATED"); 
            Signal sg = (Signal) anyClass;

            rs485.write( signalInstruction );
            rs485.write(sg.ID);

            if( sg.triggered() > 0 ) {
                rs485.write(1);
            }
            else {
                rs485.write(0);
            }
        } 

        if(anyClass instanceof Switch) {
            println("SWITCH ACTIVATED"); 	
            Switch sw = (Switch) anyClass; 
            rs485.write( turnoutInstruction );
            rs485.write(sw.ID);
            
            if( sw.triggered() > 0 ) { rs485.write(1); }
            else 					 { rs485.write(0); }
        }
    
        if(anyClass instanceof Memory) {	
            println("MEMORY ACTIVATED"); 
            clearMemoryStates();
            anyClass.setState(1);
            setSwitches(anyClass);}
        break;
        
        case settingID:
        break;
        
        case addingSwitch:
        if(Memory.class == anyClass.getClass()) {
            //memorySelected = true;
            //menu_bool = true;
            menu();
        }
        break;

        case addingSignal:
        if(Signal.class == anyClass.getClass()) {
            //menu2_bool = true;
            menu2();
        }
        break;
        
        case movingItem:
        if(mouseX > (width-2*gridSize)) { 
            locked = true;
            println("new item created");
            switch(row) {
                case 0: railItems.add( new Switch(      0,(width-2*gridSize)/gridSize,0,2,left,gridSize, 1) );println("SWITCH CREATED");    break;
                case 1: railItems.add( new Switch(     0,(width-2*gridSize)/gridSize,0,2,right,gridSize, 1) );println("SWITCH CREATED");    break;
                case 2: railItems.add( new Line(                (width-2*gridSize)/gridSize,2, 2, gridSize) );println("LINE CREATED");      break;
                case 3: railItems.add( new Curve(              (width-2*gridSize)/gridSize, 3, 2, gridSize) );println("CURVE CREATED");     break;
                case 4: railItems.add( new Detection(        0,(width-2*gridSize)/gridSize, 4, 2, gridSize) );println("DETECTOR CREATED");  break;
                case 5: railItems.add( new Memory(   0,(width-gridSize-edgeOffset)/gridSize,5, 0, gridSize) );println("MEMORY CREATED");    break;
                case 6: railItems.add( new Decoupler(0,(width-gridSize-edgeOffset)/gridSize,6, 0, gridSize) );println("DECOUPLER CREATED"); break;
                case 7: railItems.add( new Signal(0,(width-gridSize-edgeOffset) / gridSize, 7, 0,gridSize,0));println("SIGNAL CREATED");   break;
            }
            index = railItems.size() - 1;
        }
        break;
        
        case deletingItem:
        break;
        }		
}

void setSwitches(RailItem anyClass) {
    Memory mem = (Memory) anyClass; 
    int tmp;
    int[] tmpSwitches = mem.getSwitches();
    int[] tmpStates = mem.getStates(); 
        
    for(int j=0;j<255;j++){																// cross reference any ID stored in the arrays of the memory object with switch IDs
        if(tmpSwitches[j] != 0) {																
            //println(tmpSwitches[j] + " " + tmpStates[j]);
            tmp = tmpSwitches[j];
            try{
                for(int k=0;k<255;k++) {
                    anyClass = railItems.get(k);									 // use anyClass to select all switches
                    if(tmp == anyClass.getID() && anyClass instanceof Switch) {		// compares the elements out if the array with all switches' IDs
                        rs485.write(turnoutInstruction);
                        rs485.write(tmp);
                        rs485.write(tmpStates[j]);
                        
                        anyClass.setState(tmpStates[j]); } } }						 // set the state of the switch to the elements out of the array
            catch(IndexOutOfBoundsException e) {
            }
        }		 
    }
}

void setSignals(RailItem anyClass) {
    Detection det = (Detection) anyClass;
    int tmp;
    int[] tmpSignals = det.getSignals();
    int[] tmpStates  = det.getStates(); 

    for(int j = 0 ; j < 255 ; j++ ){								// cross reference any ID stored in the arrays of the memory object with switch IDs
        if(tmpSignals[j] != 0) {
            tmp = tmpSignals[j];
            try{
                for(int k = 0 ; k < 255 ; k++ ) {
                    anyClass = railItems.get(k);									// use anyClass to select all signals
                    if(tmp == anyClass.getID() && anyClass instanceof Signal) {		// compares the elements out if the array with all switches' IDs
                        rs485.write(signalInstruction);
                        rs485.write(tmp);
                        rs485.write(tmpStates[j]);
                        
                        anyClass.setState(tmpStates[j]); } } }						// set the state of the switch to the elements out of the array
            catch(IndexOutOfBoundsException e) {
            }
        }		 
    }
}
            

void mouseDragged()
{
    switch(mode) {
        case play:
        break;
        
        case settingID:
        break;
        
        case addingSwitch:
        break;
        
        case movingItem:
        if(locked) {
            RailItem anyClass = railItems.get(index);
            anyClass.setPos(column,row); }
        break;
        
        case deletingItem:
        break;
    }
}



void mouseReleased()
{
    switch(mode) {
        case settingID:
        break;
        
        case addingSwitch:
        break;
        
        case movingItem:
        locked = false;
        break;
        
        case deletingItem:
        if(railItems.size()>0 && index < railItems.size())
            railItems.remove(index);		// DELETE THE OBJECT
        locked=false;
        break;
    }
}



void keyPressed()
{	
    if(mode != play) {
        switch (key){
            case 'p':
            mode = play;
            println("mode = PLAY");
            break;
            
            case 'm':
            mode = movingItem;
            println("mode = MOVE");
            break;
            
            case 'd':
            mode = deletingItem;
            println("mode = DETELE");
            break;
            
            case 'a':
            mode = addingSwitch;
            println("mode = ADD SWITCH TO MEMORY");
            break;

            case 's':
            mode = addingSignal;
            println("mode = ADD SIGNAL TO DETECTOR");
            break;
            
            case 'n':
            mode = settingID;
            println("mode = NAME");
            assignID_bool = true;
            break;
        }
    }
    else if(key == 'p') {
        mode = IDLE;
    }
    
    switch(mode) {
        case settingID:
        if(keyCode == ENTER) {
            assignID_bool = false;
            RailItem anyClass = railItems.get(index);
            anyClass.setID(number);
            number = 0;
        }
        else {
            println("SETTING ID");
            print("CURRENT ID = ");
            number = makeNumber(number,0,255);
        }
        break;
        
        case addingSwitch:
        menu();
        break;

        case addingSignal:
        menu2();
        break;
        
        case movingItem:
        if(locked == true) {
            RailItem anyClass = railItems.get(index);
            if(keyCode == LEFT )	anyClass.turnLeft();											 // ROTATE THE OBJECT CCW		
            if(keyCode == RIGHT)	anyClass.turnRight();											// ROTATE THE OBJECT CW
            
            if(index > railItems.size()) index = railItems.size();
        }
        
        else {
            for (int i = 0; i < railItems.size(); i++) {																	// move all objects
                int Xoffset=0, Yoffset=0;
                RailItem anyClass = railItems.get(i); 
                
                //if(key == 'q') gridSize+=10; 
                //if(key == 'e') gridSize-=10;
                //anyClass.setGridSize(gridSize);
                
                if(keyCode == DOWN ) Yoffset = +1;
                if(keyCode == UP)	 Yoffset = -1;
                if(keyCode == LEFT ) Xoffset = -1;
                if(keyCode == RIGHT) Xoffset = +1; 
                anyClass.setPos(anyClass.getColumn() + Xoffset, anyClass.getRow() + Yoffset);
            } 
        }
        break;
        
        case deletingItem:
        break;
    }
}

int makeNumber(int _number, int lowerLimit, int upperLimit)
{
    if(keyCode == BACKSPACE) _number /= 10;
        else if(key >= '0' && key <= '9'){
            if(number<100)_number *= 10;
            _number += (key-'0');
            _number = constrain(_number,lowerLimit,upperLimit);
        }
        println(_number);
        return _number;
}

void menu() 
{
    if(keyCode == RIGHT) caseSelector = 1;
    if(keyCode == LEFT)	caseSelector = 0;
        
    switch(caseSelector) {
        case 0:
        if(keyCode == UP && switchID<255) switchID++;
        if(keyCode == DOWN && switchID>1) switchID--;
        switchID = makeNumber(switchID,0,255);
        break;
        
        case 1:
        if(keyCode == UP) {state = 1; }
        if(keyCode == DOWN) {state = 0; }
        break;
    }
    
    println("\r\n\r\n\r\n ADDING SWITCH TO MEMORY");
    print("ID = " + switchID);
    
    print(", state = ");
    if(state==1) print("curved");
    else		 print("straight");
    
    print(", press <ENTER> to add the switch");
    
    print("\r\n");
    switch(caseSelector) {
        case 0: // select switch
        print(" ^");
        break;
        
        case 1: // select state
        print("	       ^");
        break;
    }
    
    if(keyCode == ENTER) {
        RailItem anyClass = railItems.get(index);
        Memory mem = (Memory) anyClass; 
        mem.addSwitch(switchID, state);
        println("\r\n\r\n\r\nswtich added");
        caseSelector = 0;
        switchID = 0;
    }
}


void menu2() 
{
    if(keyCode == RIGHT) caseSelector = 1;
    if(keyCode == LEFT)	caseSelector = 0;
        
    switch(caseSelector) {
        case 0:
        if(keyCode == UP && signalID<255) signalID++;
        if(keyCode == DOWN && signalID>1) signalID--;
        signalID = makeNumber(signalID,0,255);
        break;
        
        case 1:
        if(keyCode == UP) {state = 1; }
        if(keyCode == DOWN) {state = 0; }
        break;
    }
    
    println("\r\n\r\n\r\n ADDING SIGNAL TO DETECTOR");
    print("ID = " + signalID);
    
    print(", state = ");
    if(state==1) print("GREEN");
    else		 print("RED");
    
    print(", press <ENTER> to add the signal");
    
    print("\r\n");
    switch(caseSelector) {
        case 0: // select switch
        print("   ^");
        break;
        
        case 1: // select state
        print("	          ^");
        break;
    }
    
    if(keyCode == ENTER) {
        RailItem anyClass = railItems.get(index);
        Detection det = (Detection) anyClass; 
        det.addSignal(signalID, state);
        println("\r\n\r\n\r\nsignal " + signalID + " added in state " + state);
        caseSelector = 0;
        signalID = 0;
    }
}





void saveLayout() {
    println("layout saved");
    output = createWriter("railItems.txt");
    output.println(railItems.size());
    for (int i = 0; i < railItems.size(); i++) {
        RailItem anyClass = railItems.get(i);
        if(anyClass instanceof Switch)		output.println(anyClass.getItem() + ","	+ anyClass.getID()  + "," + anyClass.getColumn()	+ "," + anyClass.getRow()+ "," + anyClass.getDirection() + "," + anyClass.getState() + "," + anyClass.getType()+ ","); 
        if(anyClass instanceof Line)		output.println(anyClass.getItem() + ","	+ 0	                + "," + anyClass.getColumn()	+ "," + anyClass.getRow()+ "," + anyClass.getDirection() + "," + anyClass.getState() + ","); 
        if(anyClass instanceof Curve)		output.println(anyClass.getItem() + ","	+ 0                 + "," + anyClass.getColumn()	+ "," + anyClass.getRow()+ "," + anyClass.getDirection() + "," + anyClass.getState() + ",");
        if(anyClass instanceof Signal)      output.println(anyClass.getItem() + ","	+ anyClass.getID()  + "," + anyClass.getColumn()	+ "," + anyClass.getRow()+ "," + anyClass.getDirection() + "," + anyClass.getState() + ","); 
        if(anyClass instanceof Decoupler)	output.println(anyClass.getItem() + ","	+ anyClass.getID()  + "," + anyClass.getColumn()	+ "," + anyClass.getRow()+ "," + anyClass.getDirection() + "," + anyClass.getState() + ",");
        if(anyClass instanceof Memory)	 {  output.print  (anyClass.getItem() + ","	+ anyClass.getID()  + "," + anyClass.getColumn()	+ "," + anyClass.getRow()+ "," + anyClass.getDirection() + "," + anyClass.getState() + ","); 
            Memory mem = (Memory) anyClass;
            int[] tmpSwitches = mem.getSwitches();
            int[] tmpStates = mem.getStates();
            for(int j=0;j<255;j++) {
                if(tmpSwitches[j]!=0) {	// if we have a switch
                    output.print(tmpSwitches[j] + "," + tmpStates[j] + ",");
                }
            }
            output.println();
        }
        if(anyClass instanceof Detection){	output.print(anyClass.getItem() + ","	+ anyClass.getID()  + "," + anyClass.getColumn()	+ "," + anyClass.getRow()+ "," + anyClass.getDirection() + "," + anyClass.getState() + ",");
            Detection det = (Detection) anyClass;
            int[] tmpSignals = det.getSignals();
            int[] tmpStates = det.getStates();
            for(int j=0;j<255;j++) {
                if(tmpSignals[j]!=0) {	// if we have a signal
                    output.print(tmpSignals[j] + "," + tmpStates[j] + ",");
                    println("signal" + tmpSignals[j] + " to " + tmpStates[j]);
                }
            }
            output.println();
        }
    }
    output.close();
}

void loadLayout()
{
    println("layout loaded");
    input = createReader("railItems.txt");
    
    try{
        line = input.readLine();
    } 
    catch (IOException e) {}
    
    int size = Integer.parseInt(line);
    
    for(int j=0; j<size; j++) {
        try {
            line = input.readLine();
        } 
        catch (IOException e) {
            line = null;
        }
        
        if (line == null) {
            // Stop reading because of an error or file is empty
            //noLoop();	
        } 
        else {
            String[] pieces = split(line, ',');
            //println();
            int item = Integer.parseInt(pieces[0]);	 // holds the type+
            int ID = Integer.parseInt(pieces[1]);
            int column = Integer.parseInt(pieces[2]);
            int row = Integer.parseInt(pieces[3]);
            int direction = Integer.parseInt(pieces[4]);
            //int state;
            state = Integer.parseInt(pieces[5]); 
            //print(pieces[4] + " ");
            
            /*for(int i=0;i<pieces.length;i++){
                print(pieces[i] + " ");
            }
            println();*/
            
            switch(item){

                case 1: // switch
                int type = Integer.parseInt(pieces[6]);
                railItems.add( new Switch(ID,column,row,direction,type,gridSize,state) );
                break;

                case 2: // line
                railItems.add( new Line(column,row,direction,gridSize) );
                break;

                case 3: // curve
                railItems.add( new Curve(column,row,direction,gridSize) );
                break;

                case 4: // detector
                railItems.add( new Detection(ID,column,row,direction,gridSize) );
                RailItem anyClass = railItems.get(j);
                int tmpSize = (pieces.length - 7)/2; // gets the proper ammount of added switches

                Detection det = (Detection) anyClass;	 
                println("for detector " + det.getID() );
                for(int i=0;i<tmpSize;i++){
                    int tmpSignal = Integer.parseInt(pieces[6+i*2]);
                    int tmpState =	Integer.parseInt(pieces[7+i*2]);
                    
                    print(" signal " + tmpSignal + " added in " );
                    if(tmpState == 0) print("green");
                    if(tmpState == 1) print("red");
                    println(" state");
                    det.addSignal(tmpSignal,tmpState); }
                break;

                case 5: // memory
                railItems.add( new Memory	(ID,column,row,direction,gridSize));
                RailItem anyClass2 = railItems.get(j);
                int tmpSize2 = (pieces.length - 7)/2; // gets the proper ammount of added switches
                Memory mem = (Memory) anyClass2;	 
                println("for memory " + mem.getID() );
                for(int i=0;i<tmpSize2;i++){
                    int tmpSwitch = Integer.parseInt(pieces[6+i*2]);
                    int tmpState =	Integer.parseInt(pieces[7+i*2]);
                    
                    print(" switch " + tmpSwitch + " added in " );
                    if(tmpState == 0) print("straight");
                    if(tmpState == 1) print("curved");
                    println(" position");
                    mem.addSwitch(tmpSwitch,tmpState); }
                break; 
                
                case 6: // Decoupler
                railItems.add(new Decoupler(ID,column,row,direction,gridSize) );
                break;

                case 7: // Signal
                railItems.add(new Signal(ID,column,row,direction,gridSize, 1) );
                break;
            }
        }
    } 
}
