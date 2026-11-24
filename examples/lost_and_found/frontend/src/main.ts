import { ServiceClient } from 'skir-client';
import {
  AddItem,
  AddItemRequest,
  ListItems,
  ListItemsRequest,
  ReuniteItem,
  ReuniteItemRequest,
  LostItem,
  ItemStatus,
} from '../skirout/lost_and_found';

// Create Skir client pointing to our backend
const client = new ServiceClient('http://localhost:8080/api');

// Current filter state
let currentFilter: ItemStatus | null = null;

// Initialize the app
async function init() {
  setupEventListeners();
  await loadItems();
}

// Set up event listeners
function setupEventListeners() {
  // Form submission
  const form = document.getElementById('addItemForm') as HTMLFormElement;
  form.addEventListener('submit', handleAddItem);

  // Filter buttons
  const filterButtons = document.querySelectorAll('.filter-btn');
  filterButtons.forEach(button => {
    button.addEventListener('click', (e) => {
      const target = e.target as HTMLButtonElement;
      const filter = target.dataset.filter;
      
      // Update active state
      filterButtons.forEach(btn => btn.classList.remove('active'));
      target.classList.add('active');
      
      // Set filter
      if (filter === 'all') {
        currentFilter = null;
      } else if (filter === 'LOST') {
        currentFilter = ItemStatus.LOST;
      } else if (filter === 'FOUND') {
        currentFilter = ItemStatus.FOUND;
      } else if (filter === 'REUNITED') {
        currentFilter = ItemStatus.REUNITED;
      }
      
      // Reload items
      loadItems();
    });
  });
}

// Handle form submission to add a new item
async function handleAddItem(e: Event) {
  e.preventDefault();
  
  const form = e.target as HTMLFormElement;
  
  const nameInput = document.getElementById('itemName') as HTMLInputElement;
  const locationInput = document.getElementById('location') as HTMLInputElement;
  const categoryInput = document.getElementById('category') as HTMLSelectElement;
  const statusInput = document.getElementById('status') as HTMLSelectElement;
  const contactInput = document.getElementById('contact') as HTMLInputElement;
  
  // Map string value to ItemStatus instance
  const statusValue = statusInput.value === 'LOST' ? ItemStatus.LOST : ItemStatus.FOUND;
  
  const request = AddItemRequest.create({
    name: nameInput.value,
    location: locationInput.value,
    category: categoryInput.value,
    status: statusValue,
    contact: contactInput.value,
  });
  
  try {
    const response = await client.invokeRemote(AddItem, request);
    console.log('Item added:', response.item);
    
    // Reset form
    form.reset();
    
    // Reload items
    await loadItems();
    
    // Show success message
    alert(`✅ Successfully reported: ${response.item.name}`);
  } catch (error) {
    console.error('Error adding item:', error);
    alert('❌ Error adding item. Please try again.');
  }
}

// Load and display items
async function loadItems() {
  const container = document.getElementById('itemsContainer')!;
  container.innerHTML = '<div class="loading">Loading items...</div>';
  
  try {
    const request = ListItemsRequest.create({
      status: currentFilter,
    });
    
    const response = await client.invokeRemote(ListItems, request);
    const items = response.items;
    
    if (items.length === 0) {
      container.innerHTML = `
        <div class="empty-state">
          <svg viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
          </svg>
          <p>No items found</p>
          <p style="font-size: 0.9rem; margin-top: 8px;">Be the first to report an item!</p>
        </div>
      `;
      return;
    }
    
    // Sort items: most recent first
    const sortedItems = [...items].sort((a, b) => Number(b.timestamp) - Number(a.timestamp));
    
    container.innerHTML = `
      <div class="items-grid">
        ${sortedItems.map(item => renderItem(item)).join('')}
      </div>
    `;
    
    // Add event listeners to reunite buttons
    sortedItems.forEach(item => {
      if (item.status !== ItemStatus.REUNITED) {
        const btn = document.getElementById(`reunite-${item.id}`);
        if (btn) {
          btn.addEventListener('click', () => handleReunite(item.id));
        }
      }
    });
  } catch (error) {
    console.error('Error loading items:', error);
    container.innerHTML = `
      <div class="error">
        ❌ Error loading items. Make sure the backend server is running on http://localhost:8080
      </div>
    `;
  }
}

// Render a single item card
function renderItem(item: LostItem): string {
  // Get the status kind to determine CSS class
  const statusKind = item.status.union.kind;
  const statusClass = statusKind.toLowerCase();
  const date = new Date(Number(item.timestamp) * 1000).toLocaleDateString();
  const time = new Date(Number(item.timestamp) * 1000).toLocaleTimeString();
  
  let statusBadge = '';
  if (item.status === ItemStatus.LOST) {
    statusBadge = '<span class="item-status status-lost">Lost</span>';
  } else if (item.status === ItemStatus.FOUND) {
    statusBadge = '<span class="item-status status-found">Found</span>';
  } else if (item.status === ItemStatus.REUNITED) {
    statusBadge = '<span class="item-status status-reunited">Reunited ✅</span>';
  }
  
  const reuniteButton = item.status !== ItemStatus.REUNITED
    ? `
      <div class="item-actions">
        <button class="reunite-btn" id="reunite-${item.id}">
          Mark as Reunited ✨
        </button>
      </div>
    `
    : '';
  
  return `
    <div class="item-card ${statusClass}">
      <div class="item-header">
        <div class="item-name">${escapeHtml(item.name)}</div>
        ${statusBadge}
      </div>
      <div class="item-details">
        <div><strong>📍 Location:</strong> ${escapeHtml(item.location)}</div>
        <div><strong>🏷️ Category:</strong> ${escapeHtml(item.category)}</div>
        <div><strong>📧 Contact:</strong> ${escapeHtml(item.contact)}</div>
        <div><strong>🕐 Reported:</strong> ${date} at ${time}</div>
      </div>
      ${reuniteButton}
    </div>
  `;
}

// Handle reunite button click
async function handleReunite(itemId: string) {
  if (!confirm('Mark this item as reunited?')) {
    return;
  }
  
  try {
    const request = ReuniteItemRequest.create({ id: itemId });
    const response = await client.invokeRemote(ReuniteItem, request);
    
    if (response.success) {
      await loadItems();
      alert('🎉 Item marked as reunited!');
    } else {
      alert('❌ Item not found');
    }
  } catch (error) {
    console.error('Error reuniting item:', error);
    alert('❌ Error marking item as reunited. Please try again.');
  }
}

// Escape HTML to prevent XSS
function escapeHtml(text: string): string {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Start the app
init();
