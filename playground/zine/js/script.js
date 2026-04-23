const leaves = document.querySelectorAll('.page');
const scene = document.getElementById('scene');
const beep = document.getElementById('beepSound'); // <--- THIS LINE IS MISSING
const totalLeaves = leaves.length;
let currentLeaf = 0;
let isAnimating = false;

function updateView() {
    console.log("Current Leaf Position:", currentLeaf);
    
    leaves.forEach((leaf, index) => {
        if (index < currentLeaf) {
            leaf.classList.add('flipped');
            leaf.style.zIndex = index;
        } else {
            leaf.classList.remove('flipped');
            leaf.style.zIndex = totalLeaves - index;
        }
    });

    scene.classList.remove('open', 'last-page');
    if (currentLeaf > 0 && currentLeaf < totalLeaves) {
        scene.classList.add('open');
    } else if (currentLeaf === totalLeaves) {
        scene.classList.add('last-page');
    }
}

function playLimitSound() {
    if (beep) {
        beep.pause();         // Stop any current playing sound
        beep.currentTime = 0;  // Reset to the beginning
        beep.play().catch(e => console.log("Audio play blocked or failed:", e));
    }
    
    // Add the shake animation for visual feedback
    const book = document.getElementById('zine');
    book.classList.add('limit-reached');
    setTimeout(() => book.classList.remove('limit-reached'), 400);
}

function goNext() {
    if (isAnimating) return;
    if (currentLeaf < totalLeaves) {
        isAnimating = true;
        currentLeaf++;
        updateView();
        setTimeout(() => { isAnimating = false; }, 850);
    } else {
        // We are at the end!
        playLimitSound();
    }
}

function goPrev() {
    if (isAnimating) return;
    if (currentLeaf > 0) {
        isAnimating = true;
        currentLeaf--;
        updateView();
        setTimeout(() => { isAnimating = false; }, 850);
    } else {
        // We are at the beginning!
        playLimitSound();
    }
}

// Ensure the click listener is targeting the right thing
document.addEventListener('mousedown', (e) => {
    if (isAnimating) return;
    
    // Check if the click was on the left or right side of the window
    if (e.clientX > window.innerWidth / 2) {
        goNext();
    } else {
        goPrev();
    }
});

// Key navigation
window.addEventListener('keydown', (e) => {
    if (e.key === "ArrowRight") goNext();
    if (e.key === "ArrowLeft") goPrev();
});

// Initial draw
updateView();
