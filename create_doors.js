const fs = require('fs');
const path = require('path');

const spritesDir = path.join(__dirname, 'assets', 'sprites');

// Closed Door (64x64)
const doorClosedSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <!-- Stone arch frame -->
  <rect width="64" height="64" fill="#181b22"/>
  <rect x="0" y="0" width="8" height="64" fill="#383f4f"/>
  <rect x="56" y="0" width="8" height="64" fill="#383f4f"/>
  <rect x="0" y="0" width="64" height="8" fill="#4d566b"/>
  
  <!-- Heavy wood door panels -->
  <rect x="8" y="8" width="48" height="56" fill="#5c2e0b"/>
  <line x1="32" y1="8" x2="32" y2="64" stroke="#2e1405" stroke-width="2"/>
  
  <!-- Wood grain planks -->
  <rect x="10" y="10" width="20" height="52" fill="#78350f" rx="1"/>
  <rect x="34" y="10" width="20" height="52" fill="#78350f" rx="1"/>

  <!-- Iron reinforcement bands -->
  <rect x="8" y="18" width="48" height="6" fill="#1e293b"/>
  <rect x="8" y="44" width="48" height="6" fill="#1e293b"/>
  <circle cx="14" cy="21" r="1.5" fill="#94a3b8"/>
  <circle cx="28" cy="21" r="1.5" fill="#94a3b8"/>
  <circle cx="36" cy="21" r="1.5" fill="#94a3b8"/>
  <circle cx="50" cy="21" r="1.5" fill="#94a3b8"/>
  <circle cx="14" cy="47" r="1.5" fill="#94a3b8"/>
  <circle cx="28" cy="47" r="1.5" fill="#94a3b8"/>
  <circle cx="36" cy="47" r="1.5" fill="#94a3b8"/>
  <circle cx="50" cy="47" r="1.5" fill="#94a3b8"/>

  <!-- Iron Ring Handle / Keyhole -->
  <circle cx="28" cy="34" r="3.5" fill="none" stroke="#f1f5f9" stroke-width="1.5"/>
  <circle cx="28" cy="31" r="1.5" fill="#94a3b8"/>
</svg>`;

// Open Door (64x64)
const doorOpenSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <!-- Floor visible beneath arch -->
  <rect width="64" height="64" fill="#2d3340"/>
  
  <!-- Stone arch frame -->
  <rect x="0" y="0" width="8" height="64" fill="#383f4f"/>
  <rect x="56" y="0" width="8" height="64" fill="#383f4f"/>
  <rect x="0" y="0" width="64" height="8" fill="#4d566b"/>
  
  <!-- Door swung open inwards (perspective slivers) -->
  <polygon points="8,8 14,14 14,64 8,64" fill="#451a03"/>
  <polygon points="56,8 50,14 50,64 56,64" fill="#451a03"/>
  <line x1="14" y1="14" x2="14" y2="64" stroke="#1e293b" stroke-width="2"/>
  <line x1="50" y1="14" x2="50" y2="64" stroke="#1e293b" stroke-width="2"/>

  <!-- Welcoming light spill -->
  <polygon points="14,14 50,14 58,64 6,64" fill="#fef08a" opacity="0.1"/>
</svg>`;

fs.writeFileSync(path.join(spritesDir, 'door_closed.svg'), doorClosedSvg.trim());
fs.writeFileSync(path.join(spritesDir, 'door_open.svg'), doorOpenSvg.trim());
console.log('Door assets generated!');
