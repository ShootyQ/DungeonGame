const fs = require('fs');
const path = require('path');

const spritesDir = path.join(__dirname, 'assets', 'sprites');
const uiDir = path.join(__dirname, 'assets', 'ui');

function writeSvg(dir, filename, content) {
  const fullPath = path.join(dir, filename);
  fs.writeFileSync(fullPath, content.trim(), 'utf8');
  console.log(`Generated: ${filename}`);
}

// 1. FLOOR TILE (64x64)
const floorSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <!-- Base dark stone -->
  <rect width="64" height="64" fill="#181b22"/>
  
  <!-- Flagstone slabs -->
  <!-- Slab 1: Top-left -->
  <rect x="2" y="2" width="28" height="28" rx="2" fill="#2d3340"/>
  <rect x="2" y="2" width="28" height="2" fill="#3f4758"/>
  <rect x="2" y="2" width="2" height="28" fill="#3f4758"/>
  <rect x="2" y="28" width="28" height="2" fill="#1b1f28"/>
  <rect x="28" y="2" width="2" height="28" fill="#1b1f28"/>
  <path d="M6 10 L14 16 L20 14" stroke="#222731" stroke-width="1" fill="none"/>

  <!-- Slab 2: Top-right -->
  <rect x="34" y="2" width="28" height="20" rx="2" fill="#282e3a"/>
  <rect x="34" y="2" width="28" height="2" fill="#384050"/>
  <rect x="34" y="2" width="2" height="20" fill="#384050"/>
  <rect x="34" y="20" width="28" height="2" fill="#181b23"/>
  <rect x="60" y="2" width="2" height="20" fill="#181b23"/>

  <!-- Slab 3: Mid-right -->
  <rect x="34" y="26" width="28" height="36" rx="2" fill="#2f3644"/>
  <rect x="34" y="26" width="28" height="2" fill="#424b5e"/>
  <rect x="34" y="26" width="2" height="36" fill="#424b5e"/>
  <rect x="34" y="60" width="28" height="2" fill="#1b1f28"/>
  <rect x="60" y="26" width="2" height="36" fill="#1b1f28"/>
  <circle cx="48" cy="42" r="2" fill="#212630"/>

  <!-- Slab 4: Bottom-left -->
  <rect x="2" y="34" width="28" height="28" rx="2" fill="#262b36"/>
  <rect x="2" y="34" width="28" height="2" fill="#363e4e"/>
  <rect x="2" y="34" width="2" height="28" fill="#363e4e"/>
  <rect x="2" y="60" width="28" height="2" fill="#161920"/>
  <rect x="28" y="34" width="2" height="28" fill="#161920"/>
  <path d="M12 48 L18 54" stroke="#1d212a" stroke-width="1"/>
  
  <!-- Moss/dirt flecks -->
  <circle cx="31" cy="31" r="1.5" fill="#1f3b2b"/>
  <circle cx="33" cy="24" r="1" fill="#1f3b2b"/>
</svg>`;

// 2. WALL TILE (64x64)
const wallSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <!-- Deep shadow backing -->
  <rect width="64" height="64" fill="#0f1117"/>
  
  <!-- Wall top rim (ledge depth) -->
  <rect x="0" y="0" width="64" height="14" fill="#474f61"/>
  <rect x="0" y="0" width="64" height="3" fill="#646e85"/>
  <rect x="0" y="11" width="64" height="3" fill="#2c3240"/>
  
  <!-- Row 1 Bricks -->
  <rect x="2" y="16" width="28" height="13" rx="1" fill="#383f4f"/>
  <rect x="2" y="16" width="28" height="2" fill="#4d566b"/>
  <rect x="32" y="16" width="30" height="13" rx="1" fill="#343b4a"/>
  <rect x="32" y="16" width="30" height="2" fill="#485165"/>
  
  <!-- Row 2 Bricks (offset) -->
  <rect x="2" y="31" width="14" height="14" rx="1" fill="#333947"/>
  <rect x="2" y="31" width="14" height="2" fill="#474f63"/>
  <rect x="18" y="31" width="28" height="14" rx="1" fill="#3a4151"/>
  <rect x="18" y="31" width="28" height="2" fill="#505a70"/>
  <rect x="48" y="31" width="14" height="14" rx="1" fill="#313745"/>
  <rect x="48" y="31" width="14" height="2" fill="#454d60"/>
  
  <!-- Row 3 Bricks -->
  <rect x="2" y="47" width="26" height="15" rx="1" fill="#2b313d"/>
  <rect x="30" y="47" width="32" height="15" rx="1" fill="#292f3a"/>
  
  <!-- Bottom cast shadow -->
  <rect x="0" y="60" width="64" height="4" fill="#0a0c10" opacity="0.8"/>
</svg>`;

// 3. HERO (64x64) - Tabletop Knight
const heroSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <!-- Character Shadow / Base -->
  <ellipse cx="32" cy="56" rx="18" ry="6" fill="#0a0c10" opacity="0.6"/>
  
  <!-- Royal Blue Cloak (behind) -->
  <path d="M22 28 L16 52 L48 52 L42 28 Z" fill="#1d4ed8"/>
  <path d="M22 28 L16 52 L26 52 Z" fill="#1e40af"/>

  <!-- Body / Armor Breastplate -->
  <rect x="24" y="26" width="16" height="18" rx="3" fill="#94a3b8"/>
  <rect x="26" y="28" width="12" height="14" rx="2" fill="#cbd5e1"/>
  <!-- Gold trim belt -->
  <rect x="23" y="41" width="18" height="4" rx="1" fill="#f59e0b"/>
  <rect x="30" y="40" width="4" height="6" fill="#fbbf24"/>
  
  <!-- Legs / Greaves -->
  <rect x="25" y="45" width="6" height="10" rx="1" fill="#64748b"/>
  <rect x="33" y="45" width="6" height="10" rx="1" fill="#64748b"/>
  <rect x="24" y="53" width="8" height="4" rx="1" fill="#475569"/>
  <rect x="32" y="53" width="8" height="4" rx="1" fill="#475569"/>

  <!-- Helmet & Plume -->
  <!-- Blue plume -->
  <path d="M30 4 C28 1, 38 0, 36 12 Z" fill="#3b82f6"/>
  <path d="M32 4 C34 1, 42 2, 38 12 Z" fill="#60a5fa"/>
  <!-- Steel Greathelm -->
  <rect x="23" y="10" width="18" height="16" rx="4" fill="#94a3b8"/>
  <rect x="25" y="12" width="14" height="12" rx="2" fill="#e2e8f0"/>
  <!-- Visor slit (T-shape) -->
  <rect x="26" y="18" width="12" height="3" fill="#0f172a"/>
  <rect x="31" y="18" width="2" height="7" fill="#0f172a"/>

  <!-- Left Hand: Heater Shield -->
  <g transform="translate(10, 24)">
    <!-- Shield body -->
    <path d="M2 0 L14 0 C14 8, 12 16, 8 20 C4 16, 2 8, 2 0 Z" fill="#2563eb"/>
    <path d="M2 0 L14 0 C14 8, 12 16, 8 20 C4 16, 2 8, 2 0 Z" stroke="#fbbf24" stroke-width="1.5" fill="none"/>
    <!-- Gold heraldry cross -->
    <rect x="7" y="3" width="2" height="12" fill="#fbbf24"/>
    <rect x="4" y="6" width="8" height="2" fill="#fbbf24"/>
  </g>

  <!-- Right Hand: Steel Longsword -->
  <g transform="translate(44, 14)">
    <!-- Blade -->
    <path d="M4 2 L6 0 L8 2 L7 24 L5 24 Z" fill="#f8fafc"/>
    <line x1="6" y1="2" x2="6" y2="24" stroke="#94a3b8" stroke-width="1"/>
    <!-- Crossguard -->
    <rect x="1" y="24" width="10" height="3" rx="1" fill="#f59e0b"/>
    <!-- Grip & Pommel -->
    <rect x="4.5" y="27" width="3" height="6" fill="#78350f"/>
    <circle cx="6" cy="34" r="2" fill="#f59e0b"/>
  </g>
</svg>`;

// 4. MONSTER 1: GOBLIN (64x64)
const goblinSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <!-- Shadow -->
  <ellipse cx="32" cy="56" rx="16" ry="5" fill="#0a0c10" opacity="0.6"/>
  
  <!-- Goblin Body (Hunched) -->
  <!-- Ragged leather tunic -->
  <path d="M24 32 L40 32 L44 50 L20 50 Z" fill="#78350f"/>
  <rect x="22" y="43" width="20" height="3" fill="#451a03"/>
  
  <!-- Legs -->
  <rect x="23" y="49" width="6" height="7" rx="1" fill="#22c55e"/>
  <rect x="35" y="49" width="6" height="7" rx="1" fill="#22c55e"/>
  <!-- Claws/feet -->
  <rect x="21" y="54" width="9" height="3" rx="1" fill="#15803d"/>
  <rect x="34" y="54" width="9" height="3" rx="1" fill="#15803d"/>

  <!-- Goblin Head -->
  <!-- Left Ear -->
  <polygon points="12,18 24,24 22,29" fill="#16a34a"/>
  <!-- Right Ear -->
  <polygon points="52,18 40,24 42,29" fill="#16a34a"/>
  <!-- Head shape -->
  <ellipse cx="32" cy="24" rx="11" ry="10" fill="#22c55e"/>
  <!-- Beady Yellow Eyes -->
  <ellipse cx="28" cy="23" rx="2.5" ry="2" fill="#fef08a"/>
  <circle cx="28.5" cy="23" r="1.2" fill="#b45309"/>
  <ellipse cx="36" cy="23" rx="2.5" ry="2" fill="#fef08a"/>
  <circle cx="36.5" cy="23" r="1.2" fill="#b45309"/>
  <!-- Big Grin / Sharp Teeth -->
  <path d="M27 29 Q32 34 37 29" stroke="#14532d" stroke-width="2" fill="none"/>
  <polygon points="29,29 30,31 31,29" fill="#fef9c3"/>
  <polygon points="33,29 34,31 35,29" fill="#fef9c3"/>

  <!-- Left Hand / Bone Dagger -->
  <g transform="translate(42, 28) rotate(15)">
    <!-- Arm -->
    <rect x="0" y="2" width="6" height="8" rx="2" fill="#22c55e"/>
    <!-- Bone blade -->
    <path d="M3 10 L5 8 L7 10 L6 26 L4 26 Z" fill="#e2e8f0"/>
    <polygon points="5,26 3,28 7,28" fill="#cbd5e1"/>
    <!-- Crude leather wrap -->
    <rect x="3" y="10" width="4" height="4" fill="#92400e"/>
  </g>
</svg>`;

// 5. MONSTER 2: SKELETON WARRIOR (64x64)
const skeletonSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <!-- Shadow -->
  <ellipse cx="32" cy="56" rx="16" ry="5" fill="#0a0c10" opacity="0.6"/>

  <!-- Rusty Tattered Loincloth -->
  <polygon points="26,40 38,40 35,48 29,48" fill="#991b1b"/>

  <!-- Ribcage & Spine -->
  <line x1="32" y1="26" x2="32" y2="42" stroke="#e2e8f0" stroke-width="3"/>
  <!-- Ribs -->
  <path d="M26 29 Q32 31 38 29" stroke="#cbd5e1" stroke-width="2" fill="none"/>
  <path d="M25 33 Q32 35 39 33" stroke="#cbd5e1" stroke-width="2" fill="none"/>
  <path d="M27 37 Q32 39 37 37" stroke="#cbd5e1" stroke-width="2" fill="none"/>

  <!-- Pelvis -->
  <ellipse cx="32" cy="41" rx="6" ry="2" fill="#cbd5e1"/>

  <!-- Bone Legs -->
  <line x1="28" y1="42" x2="27" y2="54" stroke="#e2e8f0" stroke-width="2.5"/>
  <line x1="36" y1="42" x2="37" y2="54" stroke="#e2e8f0" stroke-width="2.5"/>
  <ellipse cx="26" cy="55" rx="3" ry="1.5" fill="#94a3b8"/>
  <ellipse cx="38" cy="55" rx="3" ry="1.5" fill="#94a3b8"/>

  <!-- Skull -->
  <rect x="26" y="12" width="12" height="11" rx="4" fill="#f8fafc"/>
  <rect x="28" y="21" width="8" height="5" rx="1" fill="#f1f5f9"/>
  <!-- Eye sockets (Glowing evil red) -->
  <circle cx="29.5" cy="17" r="2.2" fill="#18181b"/>
  <circle cx="29.5" cy="17" r="1.1" fill="#ef4444"/>
  <circle cx="34.5" cy="17" r="2.2" fill="#18181b"/>
  <circle cx="34.5" cy="17" r="1.1" fill="#ef4444"/>
  <!-- Nose cavity & teeth -->
  <polygon points="32,19 31,21 33,21" fill="#18181b"/>
  <line x1="29" y1="24" x2="35" y2="24" stroke="#334155" stroke-width="1"/>
  <line x1="30" y1="23" x2="30" y2="25" stroke="#334155" stroke-width="0.8"/>
  <line x1="32" y1="23" x2="32" y2="25" stroke="#334155" stroke-width="0.8"/>
  <line x1="34" y1="23" x2="34" y2="25" stroke="#334155" stroke-width="0.8"/>

  <!-- Cracked Bronze Helmet -->
  <path d="M25 14 C25 6, 39 6, 39 14 Z" fill="#b45309"/>
  <rect x="24" y="12" width="16" height="3" rx="1" fill="#d97706"/>
  <line x1="30" y1="8" x2="33" y2="12" stroke="#451a03" stroke-width="1"/>

  <!-- Notched Scimitar in Hand -->
  <g transform="translate(42, 22)">
    <line x1="0" y1="0" x2="-6" y2="6" stroke="#e2e8f0" stroke-width="2"/> <!-- arm -->
    <path d="M-2 4 Q12 6 8 26 Q4 20 0 10 Z" fill="#94a3b8"/>
    <!-- Scimitar notches -->
    <polygon points="5,14 7,16 6,17" fill="#18181b"/>
    <rect x="-3" y="4" width="4" height="2" fill="#b45309"/>
  </g>
</svg>`;

// 6. D6 SWORD WEAPON ICON (64x64)
const swordD6Svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <!-- Glowing magical aura backing -->
  <circle cx="32" cy="32" r="28" fill="#1e293b"/>
  <circle cx="32" cy="32" r="26" fill="#0f172a" stroke="#38bdf8" stroke-width="2"/>

  <!-- Diagonal Blade -->
  <g transform="rotate(45, 32, 32)">
    <!-- Blade tip & fuller -->
    <path d="M30 6 L32 2 L34 6 L33 36 L31 36 Z" fill="#f1f5f9"/>
    <line x1="32" y1="6" x2="32" y2="35" stroke="#94a3b8" stroke-width="1"/>
    
    <!-- D6 Crossguard: A literal isometric D6 embedded as the crossguard! -->
    <!-- Brass guard wings -->
    <rect x="20" y="36" width="24" height="4" rx="2" fill="#d97706"/>
    <!-- Central D6 cube -->
    <rect x="27" y="34" width="10" height="10" rx="2" fill="#f8fafc" stroke="#1e293b" stroke-width="1"/>
    <!-- Pips on the D6 crossguard (Face showing 6 pips) -->
    <circle cx="29.5" cy="36.5" r="1" fill="#dc2626"/>
    <circle cx="29.5" cy="39" r="1" fill="#dc2626"/>
    <circle cx="29.5" cy="41.5" r="1" fill="#dc2626"/>
    <circle cx="34.5" cy="36.5" r="1" fill="#dc2626"/>
    <circle cx="34.5" cy="39" r="1" fill="#dc2626"/>
    <circle cx="34.5" cy="41.5" r="1" fill="#dc2626"/>

    <!-- Grip & Pommel -->
    <rect x="30.5" y="44" width="3" height="10" fill="#7c2d12"/>
    <circle cx="32" cy="56" r="3" fill="#d97706"/>
    <circle cx="32" cy="56" r="1.5" fill="#f59e0b"/>
  </g>
</svg>`;

// DICE FACES (1 through 6)
function generateDieFaceSvg(number, title, subtitle, colorTheme, mainIconSvg) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
    <!-- Die Face Base -->
    <rect x="3" y="3" width="58" height="58" rx="10" fill="${colorTheme.bg}" stroke="${colorTheme.border}" stroke-width="3"/>
    <!-- Inner border glow -->
    <rect x="6" y="6" width="52" height="52" rx="7" fill="none" stroke="${colorTheme.innerBorder}" stroke-width="1.5"/>
    
    <!-- Die Pip indicator in corner -->
    <circle cx="14" cy="14" r="5" fill="${colorTheme.pipBg}"/>
    <text x="14" y="17.5" font-family="sans-serif" font-weight="900" font-size="10" text-anchor="middle" fill="${colorTheme.pipText}">${number}</text>

    <!-- Center Icon -->
    <g transform="translate(16, 12)">
      ${mainIconSvg}
    </g>

    <!-- Title / Value Banner -->
    <text x="32" y="47" font-family="sans-serif" font-weight="800" font-size="9" text-anchor="middle" fill="${colorTheme.text}">${title}</text>
    <text x="32" y="56" font-family="sans-serif" font-weight="600" font-size="7" text-anchor="middle" fill="${colorTheme.subText}">${subtitle}</text>
  </svg>`;
}

// 1: MISS (Cracked, gray)
const die1 = generateDieFaceSvg(1, 'MISS', 'Stumble', {
  bg: '#1e293b', border: '#64748b', innerBorder: '#475569',
  pipBg: '#ef4444', pipText: '#ffffff', text: '#ef4444', subText: '#94a3b8'
}, `<path d="M6 6 L26 26 M26 6 L6 26" stroke="#ef4444" stroke-width="4" stroke-linecap="round"/>`);

// 2: SLASH 2 DMG
const die2 = generateDieFaceSvg(2, 'SLASH', '2 Damage', {
  bg: '#1e293b', border: '#94a3b8', innerBorder: '#475569',
  pipBg: '#334155', pipText: '#f8fafc', text: '#f8fafc', subText: '#94a3b8'
}, `<path d="M4 28 L28 4" stroke="#e2e8f0" stroke-width="3.5" stroke-linecap="round"/>
    <line x1="14" y1="18" x2="20" y2="24" stroke="#f59e0b" stroke-width="2"/>`);

// 3: SLASH 3 DMG
const die3 = generateDieFaceSvg(3, 'SLASH', '3 Damage', {
  bg: '#1e293b', border: '#38bdf8', innerBorder: '#0284c7',
  pipBg: '#0369a1', pipText: '#f8fafc', text: '#38bdf8', subText: '#bae6fd'
}, `<path d="M4 28 L28 4" stroke="#38bdf8" stroke-width="4" stroke-linecap="round"/>
    <line x1="12" y1="16" x2="18" y2="22" stroke="#f59e0b" stroke-width="2"/>
    <circle cx="26" cy="6" r="2" fill="#38bdf8"/>`);

// 4: SLASH 4 DMG
const die4 = generateDieFaceSvg(4, 'SLASH', '4 Damage', {
  bg: '#1e293b', border: '#3b82f6', innerBorder: '#1d4ed8',
  pipBg: '#1e40af', pipText: '#ffffff', text: '#60a5fa', subText: '#bfdbfe'
}, `<path d="M4 28 L28 4" stroke="#60a5fa" stroke-width="4.5" stroke-linecap="round"/>
    <path d="M8 4 L24 20" stroke="#93c5fd" stroke-width="2.5" stroke-linecap="round"/>`);

// 5: HEAVY 6 DMG
const die5 = generateDieFaceSvg(5, 'HEAVY', '6 Damage', {
  bg: '#291807', border: '#f59e0b', innerBorder: '#b45309',
  pipBg: '#f59e0b', pipText: '#451a03', text: '#fbbf24', subText: '#fde68a'
}, `<polygon points="6,26 10,28 26,12 28,6 22,8" fill="#fbbf24"/>
    <line x1="12" y1="20" x2="24" y2="8" stroke="#451a03" stroke-width="1.5"/>`);

// 6: CRIT 9 DMG + KNOCKBACK
const die6 = generateDieFaceSvg(6, 'CRIT!', '9 DMG + PUSH', {
  bg: '#3b0707', border: '#dc2626', innerBorder: '#f87171',
  pipBg: '#dc2626', pipText: '#ffffff', text: '#fca5a5', subText: '#fecaca'
}, `<path d="M16 2 L19 10 L28 12 L21 18 L23 26 L16 21 L9 26 L11 18 L4 12 L13 10 Z" fill="#ef4444" stroke="#fbbf24" stroke-width="1.5"/>`);

// TACTICAL UI INDICATORS
// Player Move Reticle
const indicatorMoveSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <!-- Glowing cyan border brackets -->
  <path d="M4 18 L4 6 C4 4.9 4.9 4 6 4 L18 4" stroke="#38bdf8" stroke-width="4" fill="none" stroke-linecap="round"/>
  <path d="M46 4 L58 4 C59.1 4 60 4.9 60 6 L60 18" stroke="#38bdf8" stroke-width="4" fill="none" stroke-linecap="round"/>
  <path d="M60 46 L60 58 C60 59.1 59.1 60 58 60 L46 60" stroke="#38bdf8" stroke-width="4" fill="none" stroke-linecap="round"/>
  <path d="M18 60 L6 60 C4.9 60 4 59.1 4 58 L4 46" stroke="#38bdf8" stroke-width="4" fill="none" stroke-linecap="round"/>
  <!-- Central pulse circle -->
  <circle cx="32" cy="32" r="8" fill="#38bdf8" opacity="0.3"/>
  <circle cx="32" cy="32" r="4" fill="#38bdf8"/>
</svg>`;

// Player Attack Crosshair
const indicatorAttackSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <circle cx="32" cy="32" r="24" stroke="#ef4444" stroke-width="3" fill="#ef4444" opacity="0.2"/>
  <circle cx="32" cy="32" r="14" stroke="#ef4444" stroke-width="2" fill="none"/>
  <!-- Crosshairs -->
  <line x1="32" y1="4" x2="32" y2="14" stroke="#ef4444" stroke-width="3" stroke-linecap="round"/>
  <line x1="32" y1="50" x2="32" y2="60" stroke="#ef4444" stroke-width="3" stroke-linecap="round"/>
  <line x1="4" y1="32" x2="14" y2="32" stroke="#ef4444" stroke-width="3" stroke-linecap="round"/>
  <line x1="50" y1="32" x2="60" y2="32" stroke="#ef4444" stroke-width="3" stroke-linecap="round"/>
  <circle cx="32" cy="32" r="3" fill="#ef4444"/>
</svg>`;

// Enemy Attack Intent Badge
const intentEnemyAttackSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32">
  <circle cx="16" cy="16" r="14" fill="#dc2626" stroke="#fca5a5" stroke-width="2"/>
  <!-- Crossed swords -->
  <line x1="9" y1="9" x2="23" y2="23" stroke="#ffffff" stroke-width="2.5" stroke-linecap="round"/>
  <line x1="23" y1="9" x2="9" y2="23" stroke="#ffffff" stroke-width="2.5" stroke-linecap="round"/>
  <circle cx="16" cy="16" r="2" fill="#fef08a"/>
</svg>`;

// Enemy Move Intent Badge
const intentEnemyMoveSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32">
  <circle cx="16" cy="16" r="14" fill="#f59e0b" stroke="#fde68a" stroke-width="2"/>
  <!-- Arrow -->
  <path d="M16 6 L23 15 L18 15 L18 25 L14 25 L14 15 L9 15 Z" fill="#ffffff"/>
</svg>`;

// Danger Tile Hazard Overlay
const dangerTileSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <rect width="64" height="64" fill="#ef4444" opacity="0.25"/>
  <rect x="2" y="2" width="60" height="60" stroke="#ef4444" stroke-width="2" stroke-dasharray="6,4" fill="none"/>
  <line x1="8" y1="8" x2="56" y2="56" stroke="#ef4444" stroke-width="1.5" opacity="0.4"/>
  <line x1="56" y1="8" x2="8" y2="56" stroke="#ef4444" stroke-width="1.5" opacity="0.4"/>
</svg>`;

// WRITE SPRITES
writeSvg(spritesDir, 'tile_floor.svg', floorSvg);
writeSvg(spritesDir, 'tile_wall.svg', wallSvg);
writeSvg(spritesDir, 'hero.svg', heroSvg);
writeSvg(spritesDir, 'monster_goblin.svg', goblinSvg);
writeSvg(spritesDir, 'monster_skeleton.svg', skeletonSvg);
writeSvg(spritesDir, 'sword_d6.svg', swordD6Svg);

// WRITE UI / DICE / INTENTS
writeSvg(uiDir, 'die_face_1.svg', die1);
writeSvg(uiDir, 'die_face_2.svg', die2);
writeSvg(uiDir, 'die_face_3.svg', die3);
writeSvg(uiDir, 'die_face_4.svg', die4);
writeSvg(uiDir, 'die_face_5.svg', die5);
writeSvg(uiDir, 'die_face_6.svg', die6);
writeSvg(uiDir, 'indicator_move.svg', indicatorMoveSvg);
writeSvg(uiDir, 'indicator_attack.svg', indicatorAttackSvg);
writeSvg(uiDir, 'intent_enemy_attack.svg', intentEnemyAttackSvg);
writeSvg(uiDir, 'intent_enemy_move.svg', intentEnemyMoveSvg);
writeSvg(uiDir, 'danger_tile.svg', dangerTileSvg);

console.log('All assets successfully generated!');
