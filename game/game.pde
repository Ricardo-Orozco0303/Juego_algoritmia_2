import processing.sound.*;

PImage backgroundImg;
PImage playerShipImg;
PImage enemyImg;

boolean[] keys = new boolean[4]; // [A, S, D, W]

// Elementos del juego
Player player;
ArrayList<Enemy> enemies = new ArrayList<Enemy>();
ArrayList<Bullet> bullets = new ArrayList<Bullet>();
ArrayList<Particle> particles = new ArrayList<Particle>();

// Efectos de disparo
float gunFlashAlpha = 0;
boolean isFiring = false;
float recoilOffset = 0;
int score = 0;
int enemySpawnTimer = 0;
boolean gameOver = false;

// Super habilidad
boolean superAbilityActive = false;
int superAbilityCooldown = 0; // Tiempo de recarga en frames (ahora inicializado en 0)
int superAbilityTimer = 0;
int superAbilityCooldownDuration = 1800; // 30 segundos * 60 FPS
color superAbilityColor = color(255, 255, 0); // Color de la super habilidad
float superAbilityRadius = 0; // Radio de expansión de la onda
boolean superAbilityExploding = false; // Indica si la onda se está expandiendo
boolean killEnemies = false;

// Sonido
SoundFile fireSound;
SoundFile backgroundMusic; // Declarar la variable para la música de fondo

void setup() {
  size(800, 600, P2D);
  smooth();

  // Cargar imágenes con manejo de errores mejorado
  backgroundImg = loadImage("escenario1.jpeg"); // esto carga el fondo, que lleva por nombre escenario1 
  if (backgroundImg == null) {
    println("Error: No se pudo cargar el fondo. Usando fondo de estrellas.");
    createStarBackground();
  } else {
    backgroundImg.resize(width, height);
  }

  playerShipImg = loadImage("nave1.png");
  if (playerShipImg == null) {
    println("Error: No se pudo cargar la nave. Usando rectángulo como reemplazo.");
    // No es necesario asignar null, simplemente no se usará como imagen.
  } else {
    playerShipImg.resize(60, 60);
  }

  enemyImg = loadImage("enemigo1.png");
  if (enemyImg == null) {
    println("Error: No se pudo cargar el enemigo. Usando elipse como reemplazo.");
    // No es necesario asignar null, simplemente no se usará como imagen.
  } else {
    enemyImg.resize(50, 50);
  }

  // Crear jugador
  player = new Player(width/2, height - 80);

  // Crear enemigos iniciales
  for (int i = 0; i < 6; i++) {
    spawnEnemy();
  }

  // Cargar sonido
  try {
    fireSound = new SoundFile(this, "disparo.mp3");
  } catch (Exception e) {
    println("Error: No se pudo cargar el sonido de disparo: " + e.getMessage());
    fireSound = null; // Importante: Establecer a null para evitar errores posteriores
  }

  // Cargar música de fondo
  try {
    backgroundMusic = new SoundFile(this, "fondo.mp3");
    backgroundMusic.loop(); // Reproducir la música en bucle
  } catch (Exception e) {
    println("Error: No se pudo cargar la música de fondo: " + e.getMessage());
    backgroundMusic = null; // Importante: Establecer a null para evitar errores posteriores
  }

  frameRate(60);
}

void createStarBackground() {
  backgroundImg = createImage(width, height, RGB);
  backgroundImg.loadPixels();
  for (int i = 0; i < backgroundImg.pixels.length; i++) {
    backgroundImg.pixels[i] = color(10, 5, 30);
  }
  for (int i = 0; i < 300; i++) {
    int x = (int)random(width);
    int y = (int)random(height);
    float brightness = random(150, 255);
    backgroundImg.set(x, y, color(brightness));
  }
  backgroundImg.updatePixels();
}

void draw() {
  // Limpiar pantalla
  background(0);
  if (backgroundImg != null) {
    image(backgroundImg, 0, 0); // Correcta forma de la imagen
  }

  if (!gameOver) {
    updateGame();
    drawGameElements();
    drawHUD();
  } else {
    drawGameOver();
  }
}

void updateGame() {
  // Actualizar efectos
  updateEffects();

  // Genera los enemigos
  enemySpawnTimer++;
  if (enemySpawnTimer > 90) {
    spawnEnemy();
    enemySpawnTimer = 0;
  }

  // Actualizar jugador
  player.update();

  // Actualizar balas
  for (int i = bullets.size()-1; i >= 0; i--) {
    Bullet b = bullets.get(i);
    b.update();
    if (b.y < -20) {
      bullets.remove(i);
    }
  }

  // Actualizar enemigos y colisiones
  for (int i = enemies.size()-1; i >= 0; i--) {
    Enemy e = enemies.get(i);
    e.update();

    // Colisiones bala-enemigo
    for (int j = bullets.size()-1; j >= 0; j--) {
      Bullet b = bullets.get(j);
      if (dist(e.x, e.y, b.x, b.y) < 25) {
        createExplosion(e.x, e.y);
        enemies.remove(i);
        bullets.remove(j);
        score += 15;
        break; // Importante: salir del bucle de balas después de la colisión
      }
    }

    // Colisión jugador-enemigo
    if (dist(player.x, player.y + recoilOffset, e.x, e.y) < 40) {
      gameOver = true;
    }

    if (e.y > height + 60) {
      enemies.remove(i);
    }
  }

  // Actualizar super habilidad
  if (superAbilityActive) {
    superAbilityTimer++;
    if (superAbilityTimer >= 180) { // Duración de la super habilidad (3 segundos a 60 FPS)
      superAbilityActive = false;
      superAbilityTimer = 0;
      superAbilityCooldown = superAbilityCooldownDuration; // Iniciar el cooldown
      superAbilityExploding = false; // Reset the explosion
      superAbilityRadius = 0;
      killEnemies = false;
    }
  } else {
    if (superAbilityCooldown > 0) {
      superAbilityCooldown--;
    }
  }
    if (superAbilityExploding) {
    superAbilityRadius += 10; // Expand the radius
    if (superAbilityRadius > width) { // Stop expanding
      superAbilityExploding = false;
      superAbilityRadius = 0;
    }
  }
  if(killEnemies){
     for (int i = enemies.size()-1; i >= 0; i--) {
        Enemy e = enemies.get(i);
        createExplosion(e.x, e.y);
        enemies.remove(i);
        score += 15;
     }
     killEnemies = false;
  }
}

void drawGameElements() {
  // Dibujar jugador
  player.draw();

  // Dibujar balas
  for (Bullet b : bullets) {
    b.draw();
  }

  // Dibujar enemigos
  for (Enemy e : enemies) {
    e.draw();
  }

  // Dibujar partículas
  for (int i = particles.size()-1; i >= 0; i--) {
    Particle p = particles.get(i);
    p.draw();
    p.update();
    if (p.alpha <= 0) {
      particles.remove(i);
    }
  }

  // Dibujar fogonazo
  if (isFiring) {
    pushMatrix();
    translate(player.x + 10, player.y - 20); // Ajustar posición del fogonazo
    fill(255, 255, 0, gunFlashAlpha); // Color amarillo
    ellipse(0, 0, 30, 10); // Forma del fogonazo
    popMatrix();
    gunFlashAlpha -= 10; // Decrementar la transparencia
    if (gunFlashAlpha <= 0) {
      isFiring = false;
    }
  }
  if (superAbilityActive) {
    // Dibujar el efecto de la super habilidad
    drawSuperAbilityEffect();
  }
   if (superAbilityExploding) {
      drawSuperAbilityExplosion();
      if(superAbilityRadius > width/2){
        killEnemies = true;
      }
    }
}

void drawHUD() {
  // Puntaje
  textSize(20);
  fill(255);
  textAlign(LEFT);
  text("Score: " + score, 10, 30);

  // Super Habilidad
  textAlign(CENTER);
  if (superAbilityCooldown == 0) {
    fill(0, 255, 0); // Verde si está disponible
    text("Super Ability Ready (Press E)", width/2, height - 30);
  } else {
    fill(100); // Gris si está en cooldown
    text("Super Ability Cooling Down: " + (superAbilityCooldown/60) + "s", width/2, height - 30); // Mostrar tiempo restante
  }
    if(superAbilityActive){
       fill(0,255,255);
       text("Super Ability Active", width/2, height-50);
    }
}

void drawGameOver() {
  background(0, 200); // Fondo semi-transparente
  textAlign(CENTER, CENTER);
  textSize(40);
  fill(255, 0, 0);
  text("Game Over", width/2, height/2 - 20);
  textSize(20);
  fill(255);
  text("Final Score: " + score, width/2, height/2 + 20);
  text("Press R to Restart", width/2, height/2 + 50);
}

void keyPressed() {
  if (key == 'a' || key == 'A') {
    keys[0] = true;
  }
  if (key == 's' || key == 'S') {
    keys[1] = true;
  }
  if (key == 'd' || key == 'D') {
    keys[2] = true;
  }
  if (key == 'w' || key == 'W') {
    keys[3] = true;
  }
  if (key == 'e' || key == 'E') { // Activar super habilidad
    if (superAbilityCooldown == 0) {
      superAbilityActive = true;
      superAbilityTimer = 0;
      //removeAllEnemies();
      superAbilityExploding = true; // Start expanding effect
      superAbilityRadius = 0;
      killEnemies = true;
    }
  }

  if (key == ' ' ) { // Disparar con la barra espaciadora
    if (!gameOver) {
      fireBullet();
    }
  }

  if (gameOver && (key == 'r' || key == 'R')) {
    resetGame();
  }
}

void keyReleased() {
  if (key == 'a' || key == 'A') {
    keys[0] = false;
  }
  if (key == 's' || key == 'S') {
    keys[1] = false;
  }
  if (key == 'd' || key == 'D') {
    keys[2] = false;
  }
  if (key == 'w' || key == 'W') {
    keys[3] = false;
  }
}

void mousePressed() { // Ahora se dispara con la barra espaciadora, pero dejo esto por si quieres usar el mouse.
  if (!gameOver) {
    fireBullet();
  }
}

void fireBullet() {
  bullets.add(new Bullet(player.x + 10, player.y));
  isFiring = true;
  gunFlashAlpha = 255;
  recoilOffset = -5; // Aplicar retroceso
  // Reproducir sonido de disparo
  if (fireSound != null) {
    fireSound.play();
  }
}

void updateEffects() {
  recoilOffset = lerp(recoilOffset, 0, 0.1); // Suavizar el retroceso
}

void spawnEnemy() {
  float x = random(50, width - 50);
  float y = -50;
  enemies.add(new Enemy(x, y));
}

void createExplosion(float x, float y) {
  for (int i = 0; i < 30; i++) { // Más partículas
    particles.add(new Particle(x, y, random(-3, 3), random(-3, 3), color(255, random(150), 0), random(20, 40))); // Color de explosión
  }
}

void removeAllEnemies() {
  enemies.clear();
}

void resetGame() {
  gameOver = false;
  score = 0;
  enemies.clear();
  bullets.clear();
  particles.clear();
  player.x = width/2;
  player.y = height - 80;
  enemySpawnTimer = 0;
  superAbilityActive = false;
  superAbilityCooldown = 0; // Importante: Reiniciar el cooldown
  superAbilityTimer = 0;
  superAbilityExploding = false;
  superAbilityRadius = 0;
  killEnemies = false;
  for (int i = 0; i < 6; i++) { //respawn initial enemies.
    spawnEnemy();
  }
}

class Player {
  float x, y;
  float speed = 5;

  Player(float x, float y) {
    this.x = x;
    this.y = y;
  }

  void update() {
    if (keys[0]) x -= speed;
    if (keys[1]) y += speed;
    if (keys[2]) x += speed;
    if (keys[3]) y -= speed;
    x = constrain(x, 30, width - 30);
    y = constrain(y, 30, height - 30);
  }

  void draw() {
    pushMatrix();
    translate(x, y + recoilOffset); // Aplicar el retroceso al dibujar la nave
    if (playerShipImg != null) {
      image(playerShipImg, -playerShipImg.width/2, -playerShipImg.height/2);
    } else {
      fill(0, 255, 0); // Verde si no hay imagen
      triangle(-30, 15, 30, 15, 0, -30);
    }
    popMatrix();
  }
}

class Bullet {
  float x, y;
  float speed = 7;
  color bulletColor;

  Bullet(float x, float y) {
    this.x = x;
    this.y = y;
    this.bulletColor = color(255);
  }

  void update() {
    y -= speed;
  }

  void draw() {
    fill(bulletColor);
    ellipse(x, y, 8, 15);
  }
}

class Enemy {
  float x, y;
  float speed = 2;
  float originalSpeed; // Store the original speed
  float hp = 1; // Health points.

  Enemy(float x, float y) {
    this.x = x;
    this.y = y;
    this.originalSpeed = speed; // Store it.
  }

  void update() {
    y += speed;
  }

  void draw() {
    pushMatrix();
    translate(x, y);
    if (enemyImg != null) {
      image(enemyImg, -enemyImg.width/2, -enemyImg.height/2);
    } else {
      fill(255, 0, 0); // Rojo si no hay imagen
      ellipse(0, 0, 30, 30);
    }
    popMatrix();
  }
}

class Particle {
  float x, y;
  float vx, vy;
  color c;
  float alpha = 255;
  float size;

  Particle(float x, float y, float vx, float vy, color c, float size) {
    this.x = x;
    this.y = y;
    this.vx = vx;
    this.vy = vy;
    this.c = c;
    this.size = size;
  }

  void update() {
    x += vx;
    y += vy;
    alpha -= 5; // Fade out
  }

  void draw() {
    colorMode(HSB, 255);
    fill(c, alpha);
    noStroke();
    ellipse(x, y, size, size);
    colorMode(RGB);
  }
}

void drawSuperAbilityEffect() {
  // Dibujar un efecto visual para la super habilidad
  for (int i = 0; i < width; i += 20) {
    for (int j = 0; j < height; j += 20) { 
      float distance = dist(width / 2, height / 2, i, j);
      color c = lerpColor(color(255, 0, 0), superAbilityColor, map(distance, 0, width / 2, 0, 1));
      fill(c, 100); // Color y transparencia
      noStroke();
      ellipse(i, j, 15, 15);
    }
  }
  // Cambiar el color de la bala
  for (Bullet b: bullets){
    b.bulletColor = superAbilityColor;  
  }
}

void drawSuperAbilityExplosion() {
  noFill();
  stroke(superAbilityColor);
  strokeWeight(10);
  ellipse(width / 2, height / 2, superAbilityRadius, superAbilityRadius);
}
 
