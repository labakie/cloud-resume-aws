async function getVisitorCount() {
    try {
        const response = await fetch("api-gateway-invoke-url-placeholder");
        const data = await response.json();
        
        // Update visitor count in HTML
        document.getElementById("visitor-count").innerText = `Site views: ${data.visitor_count}`;
    } catch (error) {
        console.error("Error fetching visitor count:", error);
    }
}

// Call the function when the page loads
window.onload = getVisitorCount;