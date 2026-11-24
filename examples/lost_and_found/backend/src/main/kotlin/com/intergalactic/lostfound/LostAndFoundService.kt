package com.intergalactic.lostfound

import build.skir.service.Service
import com.intergalactic.lostfound.skirout.lost_and_found.*
import java.time.Instant
import java.util.UUID

/**
 * Service implementation for the Intergalactic Lost & Found.
 * Stores items in memory for simplicity.
 */
class LostAndFoundService {
    // In-memory storage for demo purposes
    private val items = mutableMapOf<String, LostItem>()

    /**
     * Add a new lost or found item.
     */
    fun addItem(
        request: AddItemRequest,
        meta: RequestMetadata,
    ): AddItemResponse {
        val id = UUID.randomUUID().toString()
        val item =
            LostItem(
                id = id,
                name = request.name,
                location = request.location,
                category = request.category,
                status = request.status,
                contact = request.contact,
                timestamp = Instant.now().epochSecond,
            )

        items[id] = item
        println("Added item: ${item.name} (${item.status}) at ${item.location}")

        return AddItemResponse(item = item)
    }

    /**
     * List all items, optionally filtered by status.
     */
    fun listItems(
        request: ListItemsRequest,
        meta: RequestMetadata,
    ): ListItemsResponse {
        val filteredItems =
            if (request.status != null) {
                items.values.filter { it.status == request.status }
            } else {
                items.values.toList()
            }

        println("Listing ${filteredItems.size} items")
        return ListItemsResponse(items = filteredItems)
    }

    /**
     * Mark an item as reunited with its owner.
     */
    fun reuniteItem(
        request: ReuniteItemRequest,
        meta: RequestMetadata,
    ): ReuniteItemResponse {
        val item = items[request.id]

        if (item == null) {
            println("Item not found: ${request.id}")
            return ReuniteItemResponse(success = false)
        }

        val updatedItem = item.copy(status = ItemStatus.REUNITED)
        items[request.id] = updatedItem

        println("Reunited item: ${updatedItem.name}")
        return ReuniteItemResponse(success = true)
    }

    /**
     * Create and configure the Skir service with all method handlers.
     */
    fun createService(): Service<RequestMetadata> {
        return Service.Builder<RequestMetadata>()
            .addMethod(AddItem) { request, meta -> addItem(request, meta) }
            .addMethod(ListItems) { request, meta -> listItems(request, meta) }
            .addMethod(ReuniteItem) { request, meta -> reuniteItem(request, meta) }
            .build()
    }
}

/**
 * Simple metadata class for HTTP requests.
 * Can be extended to include auth tokens, user ID, etc.
 */
data class RequestMetadata(
    val dummy: Boolean = false,
) {
    companion object {
        fun empty() = RequestMetadata()
    }
}
