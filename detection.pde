class Detection extends RailItem
{
  // variables
  int directionLimit = 3;
  
  // constructor
  Detection(int ID, int Xpos, int Ypos, int direction, int gridSize)
  {
    super(Xpos, Ypos, direction, gridSize);
    this.ID = ID;
    item = 4;
    
    designation = str(ID);
  }
  
  
  // functions
 
  void Draw()
  {
    fill(0);
    if(direction>3)direction-=4;
    switch(direction){
      case 2:
      line(Xpos-halveSize,Ypos,Xpos+halveSize,Ypos);
      break;
      
      case 3:
      line(Xpos-halveSize,Ypos-halveSize,Xpos+halveSize,Ypos+halveSize);
      break;
      
      case 0:
      line(Xpos,Ypos-halveSize,Xpos,Ypos+halveSize);
      break;
      
      case 1:
      line(Xpos+halveSize,Ypos-halveSize,Xpos-halveSize,Ypos+halveSize);
      break;
    }
    
    if(state == 0) fill(0,255,0);
    if(state == 1) fill(255,0,0);
    ellipse(Xpos,Ypos, halveSize,halveSize);
    fill(0);
    text(designation,Xpos,Ypos);
  }
}
