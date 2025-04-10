async function getVisitorCount() {
    try {
        const response = await fetch("https://gry5ux3ldj.execute-api.us-east-1.amazonaws.com/dev/visitor-counter");
        const data = await response.json();
        
        // Update visitor count in HTML
        document.getElementById("visitor-count").innerText = `Site views: ${data.visitor_count}`;
    } catch (error) {
        console.error("Error fetching visitor count:", error);
    }
}

// Call the function when the page loads
window.onload = getVisitorCount;