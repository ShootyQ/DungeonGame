const fs = require('fs');
const path = require('path');
const spritesDir = path.join(__dirname, 'assets', 'sprites');

// Closed Chest (64x64)
const chestClosedSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <!-- Shadow -->
  <ellipse cx="32" cy="54" rx="22" ry="7" fill="#090b0e" opacity="0.6"/>
  
  <!-- Base box -->
  <rect x="10" y="26" width="44" height="26" rx="3" fill="#78350f" stroke="#451a03" stroke-width="2"/>
  <rect x="12" y="28" width="40" height="22" fill="#92400e"/>
  
  <!-- Curved Chest Lid -->
  <path d="M8 26 C8 12, 56 12, 56 26 Z" fill="#b45309" stroke="#451a03" stroke-width="2"/>
  <path d="M11 25 C13 15, 51 15, 53 25 Z" fill="#d97706"/>

  <!-- Golden Trim Bands -->
  <rect x="16" y="16" width="6" height="36" fill="#fbbf24"/>
  <rect x="42" y="16" width="6" height="36" fill="#fbbf24"/>
  <rect x="8" y="25" width="48" height="4" fill="#fbbf24"/>

  <!-- Golden Lock / Keyhole with Glowing Ruby -->
  <rect x="27" y="25" width="10" height="12" rx="2" fill="#f59e0b" stroke="#78350f" stroke-width="1.5"/>
  <circle cx="32" cy="30" r="3" fill="#ef4444"/>
  <circle cx="32" cy="30" r="1.5" fill="#fef08a"/>
</svg>`;

// Open Chest (64x64) with Glowing Relic Die!
const chestOpenSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <!-- Shadow -->
  <ellipse cx="32" cy="54" rx="22" ry="7" fill="#090b0e" opacity="0.6"/>

  <!-- Open Lid (swung back) -->
  <path d="M10 20 C10 6, 54 6, 54 20 Z" fill="#78350f" stroke="#451a03" stroke-width="2"/>

  <!-- Golden Light Spill -->
  <polygon points="14,24 50,24 58,4 6,4" fill="#fef08a" opacity="0.25"/>

  <!-- Base box interior (dark wood) -->
  <rect x="10" y="26" width="44" height="26" rx="3" fill="#451a03" stroke="#260e02" stroke-width="2"/>
  <rect x="12" y="28" width="40" height="8" fill="#1e0a02"/>

  <!-- Gold Coins Heap -->
  <ellipse cx="32" cy="36" rx="16" ry="6" fill="#f59e0b"/>
  <circle cx="26" cy="35" r="2.5" fill="#fef08a"/>
  <circle cx="31" cy="34" r="2.5" fill="#fef08a"/>
  <circle cx="37" cy="35" r="2.5" fill="#fef08a"/>

  <!-- Floating Glowing Relic Die in chest -->
  <g transform="translate(26, 12)">
    <rect width="12" height="12" rx="2" fill="#38bdf8" stroke="#ffffff" stroke-width="1.5"/>
    <circle cx="3.5" cy="3.5" r="1" fill="#ffffff"/>
    <circle cx="8.5" cy="8.5" r="1" fill="#ffffff"/>
  </g>

  <!-- Golden Trim Bands on bottom -->
  <rect x="16" y="32" width="6" height="20" fill="#fbbf24"/>
  <rect x="42" y="32" width="6" height="20" fill="#fbbf24"/>
</svg>`;

fs.writeFileSync(path.join(spritesDir, 'chest_closed.svg'), chestClosedSvg.trim());
fs.writeFileSync(path.join(spritesDir, 'chest_open.svg'), chestOpenSvg.trim());
console.log('Chest assets generated!');
