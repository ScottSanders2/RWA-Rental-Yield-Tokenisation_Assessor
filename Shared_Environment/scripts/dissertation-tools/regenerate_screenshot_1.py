#!/usr/bin/env python3
"""
Regenerate multi-env-orchestration.png with light background and better proportions
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch
import numpy as np

# Set up the figure with light background
fig, ax = plt.subplots(1, 1, figsize=(12, 8))
fig.patch.set_facecolor('#FFFFFF')
ax.set_facecolor('#F8F9FA')

# Title
ax.set_title('Multi-Environment Docker Orchestration', fontsize=16, fontweight='bold', pad=20)

# Remove axes
ax.set_xlim(0, 12)
ax.set_ylim(0, 8)
ax.axis('off')

# Define colors
dev_color = '#E3F2FD'  # Light blue for Development
test_color = '#E8F5E9'  # Light green for Test
header_dev = '#1976D2'  # Blue header
header_test = '#388E3C'  # Green header
container_color = '#FFFFFF'
border_color = '#BDBDBD'

# Development Environment Box
dev_box = FancyBboxPatch((0.5, 4.2), 5, 3.5, boxstyle="round,pad=0.05", 
                          facecolor=dev_color, edgecolor=header_dev, linewidth=2)
ax.add_patch(dev_box)
ax.text(3, 7.4, 'DEVELOPMENT ENVIRONMENT', ha='center', fontsize=11, fontweight='bold', color=header_dev)

# Development containers
dev_containers = [
    ('rwa-dev-frontend', 'Up 5 min', '3000:3000'),
    ('rwa-dev-backend', 'Up 5 min', '8000:8000'),
    ('rwa-dev-postgres', 'Up 5 min', '5432:5432'),
    ('rwa-dev-anvil', 'Up 5 min', '8545:8545'),
]

for i, (name, status, ports) in enumerate(dev_containers):
    y_pos = 6.8 - i * 0.6
    # Container box
    container = FancyBboxPatch((0.8, y_pos - 0.25), 4.4, 0.5, boxstyle="round,pad=0.02",
                                facecolor=container_color, edgecolor=border_color, linewidth=1)
    ax.add_patch(container)
    # Green status indicator
    ax.plot(1.1, y_pos, 'o', color='#4CAF50', markersize=8)
    ax.text(1.4, y_pos, name, fontsize=9, va='center', fontfamily='monospace')
    ax.text(3.8, y_pos, status, fontsize=8, va='center', color='#666666')
    ax.text(4.8, y_pos, ports, fontsize=8, va='center', color='#1976D2', fontfamily='monospace')

# Test Environment Box
test_box = FancyBboxPatch((6.5, 4.2), 5, 3.5, boxstyle="round,pad=0.05",
                           facecolor=test_color, edgecolor=header_test, linewidth=2)
ax.add_patch(test_box)
ax.text(9, 7.4, 'TEST ENVIRONMENT', ha='center', fontsize=11, fontweight='bold', color=header_test)

# Test containers
test_containers = [
    ('rwa-test-frontend', 'Up 3 min', '3001:3000'),
    ('rwa-test-backend', 'Up 3 min', '8001:8000'),
    ('rwa-test-postgres', 'Up 3 min', '5433:5432'),
    ('rwa-test-cypress', 'Up 3 min', '-'),
]

for i, (name, status, ports) in enumerate(test_containers):
    y_pos = 6.8 - i * 0.6
    # Container box
    container = FancyBboxPatch((6.8, y_pos - 0.25), 4.4, 0.5, boxstyle="round,pad=0.02",
                                facecolor=container_color, edgecolor=border_color, linewidth=1)
    ax.add_patch(container)
    # Green status indicator
    ax.plot(7.1, y_pos, 'o', color='#4CAF50', markersize=8)
    ax.text(7.4, y_pos, name, fontsize=9, va='center', fontfamily='monospace')
    ax.text(9.8, y_pos, status, fontsize=8, va='center', color='#666666')
    ax.text(10.8, y_pos, ports, fontsize=8, va='center', color='#388E3C', fontfamily='monospace')

# Command section at bottom
cmd_box = FancyBboxPatch((0.5, 0.5), 11, 3.2, boxstyle="round,pad=0.05",
                          facecolor='#FAFAFA', edgecolor='#9E9E9E', linewidth=1)
ax.add_patch(cmd_box)
ax.text(6, 3.4, 'Docker Compose Commands', ha='center', fontsize=11, fontweight='bold', color='#424242')

# Commands
commands = [
    '$ docker-compose -f docker-compose.dev.yml up -d',
    '  ✓ Creating network "rwa_dev_network" with driver "bridge"',
    '  ✓ Creating rwa-dev-postgres ... done',
    '  ✓ Creating rwa-dev-anvil    ... done',
    '  ✓ Creating rwa-dev-backend  ... done',
    '  ✓ Creating rwa-dev-frontend ... done',
    '',
    '$ docker ps --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}"',
    '  NAMES              STATUS       PORTS',
    '  rwa-dev-frontend   Up 5 min     0.0.0.0:3000->3000/tcp',
    '  rwa-dev-backend    Up 5 min     0.0.0.0:8000->8000/tcp',
]

for i, cmd in enumerate(commands):
    y_pos = 3.0 - i * 0.22
    if cmd.startswith('$'):
        ax.text(0.8, y_pos, cmd, fontsize=8, va='center', fontfamily='monospace', color='#1565C0', fontweight='bold')
    elif cmd.startswith('  ✓'):
        ax.text(0.8, y_pos, cmd, fontsize=8, va='center', fontfamily='monospace', color='#2E7D32')
    else:
        ax.text(0.8, y_pos, cmd, fontsize=8, va='center', fontfamily='monospace', color='#424242')

# Save
plt.tight_layout()
plt.savefig('generated_screenshots/multi-env-orchestration-new.png', dpi=150, 
            facecolor='white', edgecolor='none', bbox_inches='tight')
plt.close()

print("✓ Generated: multi-env-orchestration-new.png")



