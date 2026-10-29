const fs = require('fs');
const path = require('path');
const uiDir = path.join(__dirname, 'assets', 'ui');

const fireDieSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <rect x="3" y="3" width="58" height="58" rx="10" fill="#3b0f04" stroke="#f97316" stroke-width="3"/>
  <rect x="6" y="6" width="52" height="52" rx="7" fill="none" stroke="#ea580c" stroke-width="1.5"/>
  <circle cx="14" cy="14" r="5" fill="#ea580c"/>
  <text x="14" y="17.5" font-family="sans-serif" font-weight="900" font-size="10" text-anchor="middle" fill="#ffffff">🔥</text>

  <!-- Big Central Flame -->
  <g transform="translate(18, 10)">
    <path d="M14 2 C14 2, 22 10, 20 18 C26 14, 26 22, 22 28 C16 34, 4 30, 6 22 C6 18, 10 14, 8 10 C14 10, 10 4, 14 2 Z" fill="#ef4444"/>
    <path d="M14 8 C14 8, 19 14, 18 20 C22 17, 21 23, 18 26 C14 30, 8 27, 9 22 C9 19, 11 16, 10 14 C14 14, 12 9, 14 8 Z" fill="#f59e0b"/>
    <path d="M14 15 C14 15, 17 19, 16 22 C18 21, 16 25, 14 26 C12 27, 10 26, 11 23 C11 21, 12 19, 12 18 C14 18, 13 16, 14 15 Z" fill="#fef08a"/>
  </g>

  <text x="32" y="47" font-family="sans-serif" font-weight="800" font-size="9" text-anchor="middle" fill="#fdba74">FLAME RUNE</text>
  <text x="32" y="56" font-family="sans-serif" font-weight="600" font-size="7" text-anchor="middle" fill="#fed7aa">8 DMG + BURN</text>
</svg>`;

fs.writeFileSync(path.join(uiDir, 'die_face_fire.svg'), fireDieSvg.trim());
console.log('Fire die face generated!');
