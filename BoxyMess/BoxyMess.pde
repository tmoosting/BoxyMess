// pure data communication imports
import oscP5.*;
import netP5.*;

// 2d physics imports
import shiffman.box2d.*;
import org.jbox2d.collision.shapes.*;
import org.jbox2d.common.*;
import org.jbox2d.dynamics.*;
import org.jbox2d.dynamics.joints.*;


OscP5 osc;
NetAddress puredata; 
Box2DProcessing box2d; 
ArrayList<SoundBox> boxes;
ArrayList<SoundBox> tempBoxes;
ArrayList<Boundary> boundaries;
float lineHeight = 120;
int fireOdds = 5; // out of 100, called every frame!
int maxFireOdds = 150; // 
boolean mouseDown = false;
boolean boundaryActive = false;
int duration = 800; 

void setup () {
  size(800, 600);
  frameRate(60);
  osc = new OscP5(this, 12000);
  puredata = new NetAddress("127.0.0.1", 8000); 
  sendMsg("/vol", 0.5);
  sendMsg("/bypass", 1);

  box2d = new Box2DProcessing(this);
  box2d.createWorld();
  box2d.setGravity(0, -5); 
  boxes = new ArrayList<SoundBox>();
  tempBoxes = new ArrayList<SoundBox>(); 
  boundaries = new ArrayList<Boundary>();
}

void draw() {

  background (244,241,244);
  line(0, height-lineHeight, width, height-lineHeight);
  fill (0, 0, 0);
  text ("Click anywhere to spawn a SoundBox. Height makes it louder and the x-axis determines its frequency. ", 25, 25);
  text ("SoundBoxes will randomly fire their sounds when they get below the line.", 25, 45);
  text ("SoundBoxes are created with a ramp time called Duration.", 25, 65);
  
  text ("Toggle a preserving Boundary with 'b'. ", 25, 105);  
  text ("Fire Chance: "+ fireOdds + "/300  (adjust with + and -)", 25, 125);
  text ("Duration: "+ duration + "  (adjust with UP and DOWN)", 25, 145);
  for (Boundary wall : boundaries) {
    wall.display();
  }

  box2d.step();

  //for each box send a message to pd with position
  for (SoundBox b : boxes) { 
    if (b != null) {
      b.display();
      b.attemptFire();
      Vec2 pos = box2d.getBodyPixelCoord(b.body);
      sendMsg("/boxX", pos.x);
      sendMsg("/boxY", pos.y);
      if (pos.y > height-lineHeight) {
        b.fireSounds = true;
      }
    }
  }

  // check which boxes are offscreen and add to a templist to safely delete them
  tempBoxes = new ArrayList <SoundBox>();
  for (SoundBox b : boxes) { 
    if (CheckBoxForDestroying(b) == true) {
      tempBoxes.add(b);
    }
  }
  // delete them here
  for (SoundBox b : tempBoxes) { 
    boxes.remove(b);
    box2d.destroyBody(b.body) ;
  }

  // set fireodds depending on number of boxes 
  //  fireOdds = maxFireOdds - boxes.size();
  // text (fireOdds, 25, 25);
  // if (fireOdds < minFireOdds) {
  //   fireOdds = minFireOdds;
  // }
  // text (fireOdds, 25, 25);
} 
void keyPressed () {
  if (key == '=' || key == '+') {
    fireOdds++;
    if (fireOdds >= maxFireOdds) {
      fireOdds = maxFireOdds;
    }
  }
  if (key == '-') {
    fireOdds--;
    if (fireOdds <= 0) {
      fireOdds = 0;
    }
  }


  if (key == CODED) {
    if (keyCode == UP) {
      duration+=10;
    }
    if (keyCode == DOWN) {
      duration-=10;
      if (duration <= 0) {
        duration = 0;
      }
    }
  }



  if (key == 'b' || key == 'B') {
    if (boundaryActive == false) {
      boundaries.add(new Boundary(width/2, height-5, width, 10));
      boundaryActive = true;
    } else {
      box2d.destroyBody(boundaries.get(0).b);
      boundaries = new ArrayList <Boundary>();
      boundaryActive = false;
      for (SoundBox b : boxes) { 
        Vec2 pos = box2d.getBodyPixelCoord(b.body);

        if (pos.y > height-lineHeight) {
          //  b.body.setLinearVelocity(new Vec2(random(-5, 50), random(2, 50)));
          //  b.body.setAngularVelocity(random(-5, 50));
        }
      }
    }
  }
}
void mouseReleased() {
  mouseDown =false;
}
void mouseMoved () {
  if (mouseDown == true) {
    //  SoundBox box = new SoundBox(mouseX, mouseY, (width - mouseX + 100), ((float)(float)(height - mouseY)/(float) height), duration);
    //   boxes.add(box);
  }
}
void mousePressed() {
  mouseDown = true;
  SoundBox box = new SoundBox(mouseX, mouseY, (width - mouseX + 100), ((float)(float)(height - mouseY)/(float) height), duration   );
  boxes.add(box);
  sendMsg("/freq", width - mouseX + 100);
  sendMsg("/vol", (float)(float)(height - mouseY)/(float) height) ;
  sendMsg("/bang", 1);
  sendMsg("/boxStay", duration);
}

void sendMsg(String label, float data) {
  OscMessage msg = new OscMessage(label);
  msg.add(data);
  osc.send(msg, puredata);
}

boolean CheckBoxForDestroying (SoundBox box) { 
  Vec2 pos = box2d.getBodyPixelCoord(box.body); 
  if (pos.y > height || pos.x > width || pos.x < 0) {
    return true;
  } 
  return false;
}

class SoundBox {

  Body body;
  float boxWidth;
  float boxHeight;
  float frequency;
  float volume;
  float stayLength;
  boolean fireSounds = false;

  // Constructor
  SoundBox(float x, float y, float freq, float vol, int duration) {
    boxWidth = random(4, 16);
    boxHeight = random(4, 16);
    frequency = freq; 
    volume = vol;
    stayLength = duration;
    makeBody(new Vec2(x, y), boxWidth, boxHeight);
  }

  void attemptFire () {
    if (fireSounds == true) {
      int randomNr =int(random(0, 300));
      if (randomNr < fireOdds) {
        // make some noise!!
        sendMsg("/freq", frequency);
        sendMsg("/vol", volume) ;
        sendMsg("/bang", 1);
        sendMsg("/boxStay", stayLength);
      }
    }
  }


  // Rest of the code and comments in this class are copied
  // from original author at // https://github.com/SIGMusic/processing-pd-example 


  // Drawing the box 
  void display() { 
    Vec2 pos = box2d.getBodyPixelCoord(body); 
    float a = body.getAngle(); 
    rectMode(CENTER);
    pushMatrix();
    translate(pos.x, pos.y);
    rotate(-a);
    float r = ((width-pos.x)/width) * 255;
    float g = 102;
    float b = 102;
    fill(r, g, b);
    stroke(0);
    rect(0, 0, boxWidth, boxHeight);
    popMatrix();
  }

  // This function adds the rectangle to the box2d world
  void makeBody(Vec2 center, float w_, float h_) {

    // Define a polygon (this is what we use for a rectangle)
    PolygonShape sd = new PolygonShape();
    float box2dW = box2d.scalarPixelsToWorld(w_/2);
    float box2dH = box2d.scalarPixelsToWorld(h_/2);
    sd.setAsBox(box2dW, box2dH);

    // Define a fixture
    FixtureDef fd = new FixtureDef();
    fd.shape = sd;
    // Parameters that affect physics
    fd.density = 1;
    fd.friction = 0.3;
    fd.restitution = 0.5;

    // Define the body and make it from the shape
    BodyDef bd = new BodyDef();
    bd.type = BodyType.DYNAMIC;
    bd.position.set(box2d.coordPixelsToWorld(center));

    body = box2d.createBody(bd);
    body.createFixture(fd);

    // Give it some initial random velocity
    body.setLinearVelocity(new Vec2(random(-5, 5), random(2, 5)));
    body.setAngularVelocity(random(-5, 5));
  }
}
class Boundary {

  // this class entirely copied from the Blobby example of box2d!!


  // A boundary is a simple rectangle with x,y,width,and height
  float x;
  float y;
  float w;
  float h;

  // But we also have to make a body for box2d to know about it
  Body b;

  Boundary(float x_, float y_, float w_, float h_) {
    x = x_;
    y = y_;
    w = w_;
    h = h_;

    // Define the polygon
    PolygonShape sd = new PolygonShape();
    // Figure out the box2d coordinates
    float box2dW = box2d.scalarPixelsToWorld(w/2);
    float box2dH = box2d.scalarPixelsToWorld(h/2);
    // We're just a box
    sd.setAsBox(box2dW, box2dH);


    // Create the body
    BodyDef bd = new BodyDef();
    bd.type = BodyType.STATIC;
    bd.position.set(box2d.coordPixelsToWorld(x, y));
    b = box2d.createBody(bd);

    // Attached the shape to the body using a Fixture
    b.createFixture(sd, 1);
  }

  // Draw the boundary, if it were at an angle we'd have to do something fancier
  void display() {
    fill(0);
    stroke(0);
    rectMode(CENTER);
    rect(x, y, w, h);
  }
}
