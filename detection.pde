class Detection extends RailItem
{
    // variables
    //int directionLimit = 3; // ? forgot what it was, seems unused
    int signalIndex = 0;

    int[] attachedSignals = new int[256];
    int[] signalStates = new int[256];

    // constructor
    Detection(int ID, int Xpos, int Ypos, int direction, int gridSize)
    {
        super(Xpos, Ypos, direction, gridSize);
        this.ID = ID;
        item = 4;
        
        designation = str(ID);
    }


    // functions

    int[] getSignals()
    {
        return attachedSignals;
    }
    
    int[] getStates()
    {
        return  signalStates;
    }

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
        
        if(state == 0) fill(200,0,0);
        if(state == 1) fill(125,250,0);
        ellipse(Xpos,Ypos, halveSize,halveSize);
        fill(0);
        text(designation,Xpos,Ypos);
    }

    void addSignal(int signalID, int state)  
    {
        attachedSignals[signalIndex] = signalID;
        signalStates[signalIndex++] = state;
    }
}
