document.body.addEventListener('htmx:afterSwap', function(event) {
    if (event.target.id === 'messages') {
        setTimeout(function() {
            event.target.style.display = 'none';
        }, 3000); // 3000 milliseconds = 3 seconds
    }
});

document.body.addEventListener('htmx:beforeSwap', function(event) {
    if (event.target.id === 'messages') {
        event.target.style.display = 'block';
    }
});
