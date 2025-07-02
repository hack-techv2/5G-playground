// Global variables
let challengesData = null;
let currentChallenge = null;

document.addEventListener('DOMContentLoaded', function() {
    // Initialize the application
    initializeApp();
    
    // Smooth scrolling for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            e.preventDefault();
            
            const targetId = this.getAttribute('href');
            const targetElement = document.querySelector(targetId);
            
            if (targetElement) {
                window.scrollTo({
                    top: targetElement.offsetTop - 70,
                    behavior: 'smooth'
                });
            }
        });
    });

    // Check status of all challenges (disabled - no port configuration in challenges)
    // checkAllChallengeStatus();

    // Add hover effects to challenge cards
    const challengeCards = document.querySelectorAll('.challenge-card');
    challengeCards.forEach(card => {
        card.addEventListener('mouseenter', function() {
            this.style.transform = 'translateY(-5px)';
        });
        
        card.addEventListener('mouseleave', function() {
            this.style.transform = 'translateY(0)';
        });
    });
});

// Initialize the application
async function initializeApp() {
    try {
        await loadChallengesData();
        validateStoredFlags(); // Validate all stored flags on page load
        populatePlatformStats();
        createCategoryFilters();
        renderChallenges();
        setupEventListeners();
    } catch (error) {
        console.error('Failed to initialize app:', error);
        showError('Failed to load challenges. Please refresh the page.');
    }
}

// Load challenges data from JSON
async function loadChallengesData() {
    try {
        const response = await fetch('challenges.json');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        challengesData = await response.json();
    } catch (error) {
        console.error('Error loading challenges data:', error);
        throw error;
    }
}

// Helper functions for solved challenges storage
function getSolvedChallenges() {
    try {
        const stored = localStorage.getItem('solvedChallenges');
        console.log('Raw localStorage data for solvedChallenges:', stored);
        
        if (!stored || stored === 'null' || stored === 'undefined') {
            return [];
        }
        
        const parsed = JSON.parse(stored);
        console.log('Parsed solvedChallenges data:', parsed);
        
        if (!Array.isArray(parsed)) {
            console.warn('Parsed data is not an array, returning empty array. Data:', parsed);
            return [];
        }
        
        return parsed;
    } catch (error) {
        console.error('Error parsing solved challenges from localStorage:', error);
        console.log('Problematic localStorage value:', localStorage.getItem('solvedChallenges'));
        return [];
    }
}

function setSolvedChallenges(solvedChallenges) {
    try {
        localStorage.setItem('solvedChallenges', JSON.stringify(solvedChallenges));
    } catch (error) {
        console.error('Error saving solved challenges to localStorage:', error);
    }
}

function addSolvedChallenge(challengeId, flag) {
    const solvedChallenges = getSolvedChallenges();
    
    // Check if challenge is already solved
    const existingIndex = solvedChallenges.findIndex(([id, _]) => id == challengeId);
    
    if (existingIndex >= 0) {
        // Update existing entry
        solvedChallenges[existingIndex] = [challengeId, flag];
    } else {
        // Add new entry
        solvedChallenges.push([challengeId, flag]);
    }
    
    setSolvedChallenges(solvedChallenges);
}



// Validate all stored flags on page load and remove invalid ones
function validateStoredFlags() {
    if (!challengesData) {
        return;
    }
    
    let flagsChanged = false;
    let solvedChallenges = getSolvedChallenges();
    let validSolvedChallenges = [];
    
    // Ensure solvedChallenges is an array before iterating
    if (!Array.isArray(solvedChallenges)) {
        console.warn('solvedChallenges is not an array, resetting to empty array:', solvedChallenges);
        solvedChallenges = [];
        flagsChanged = true;
    }
    
    // Validate each stored solution
    try {
        for (const entry of solvedChallenges) {
            // Ensure entry is an array with at least 2 elements
            if (!Array.isArray(entry) || entry.length < 2) {
                console.warn('Invalid entry format, skipping:', entry);
                flagsChanged = true;
                continue;
            }
            
            const [challengeId, submittedFlag] = entry;
            const challenge = challengesData.challenges.find(c => c.id == challengeId);
            
            if (challenge) {
                // Check if the stored flag is still valid for this challenge
                const isValidFlag = challenge.flags.some(flag => {
                    if (flag.case_sensitive) {
                        return submittedFlag === flag.value;
                    } else {
                        return submittedFlag.toLowerCase() === flag.value.toLowerCase();
                    }
                });
                
                if (isValidFlag) {
                    // Flag is still valid, keep it
                    validSolvedChallenges.push([challengeId, submittedFlag]);
                } else {
                    // Flag is no longer valid, remove it
                    console.log(`Removing invalid flag for challenge ${challengeId}: ${submittedFlag}`);
                    flagsChanged = true;
                }
            } else {
                // Challenge no longer exists, remove the flag
                console.log(`Removing flag for non-existent challenge ${challengeId}: ${submittedFlag}`);
                flagsChanged = true;
            }
        }
    } catch (error) {
        console.error('Error validating stored flags:', error);
        console.log('solvedChallenges data:', solvedChallenges);
        // Reset to empty array if there's an error
        validSolvedChallenges = [];
        flagsChanged = true;
    }
    
    // Clean up old individual challenge ID keys from localStorage (migration)
    const allChallengeIds = challengesData.challenges.map(c => c.id.toString());
    for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key && /^\d+$/.test(key) && allChallengeIds.includes(key)) {
            console.log(`Migrating old format flag for challenge ${key}`);
            const oldFlag = localStorage.getItem(key);
            const challenge = challengesData.challenges.find(c => c.id == key);
            
            if (challenge && oldFlag) {
                // Validate the old flag before migrating
                const isValidFlag = challenge.flags.some(flag => {
                    if (flag.case_sensitive) {
                        return oldFlag === flag.value;
                    } else {
                        return oldFlag.toLowerCase() === flag.value.toLowerCase();
                    }
                });
                
                if (isValidFlag) {
                    // Add to valid solved challenges if not already there
                    const exists = validSolvedChallenges.find(([id, flag]) => id == key);
                    if (!exists) {
                        validSolvedChallenges.push([parseInt(key), oldFlag]);
                        flagsChanged = true;
                    }
                }
            }
            
            // Remove the old individual key
            localStorage.removeItem(key);
            flagsChanged = true;
        }
    }
    
    if (flagsChanged) {
        setSolvedChallenges(validSolvedChallenges);
        console.log('Invalid flags removed and storage format updated');
    }
}

// Populate platform statistics
function populatePlatformStats() {
    if (!challengesData) return;
    
    document.getElementById('total-challenges').textContent = challengesData.platform.total_challenges;
    document.getElementById('total-points').textContent = challengesData.platform.total_points;
    document.getElementById('categories-count').textContent = challengesData.platform.categories.length;
}

// Create category filter buttons
function createCategoryFilters() {
    if (!challengesData) return;
    
    const filterContainer = document.getElementById('category-filters');
    const allButton = filterContainer.querySelector('[data-category="all"]');
    
    challengesData.platform.categories.forEach(category => {
        const button = document.createElement('button');
        button.className = 'filter-btn';
        button.dataset.category = category;
        button.textContent = category;
        button.addEventListener('click', () => filterChallenges(category));
        filterContainer.appendChild(button);
    });
    
    // Add event listener to "All" button
    allButton.addEventListener('click', () => filterChallenges('all'));
}

// Filter challenges by category
function filterChallenges(category) {
    // Update active filter button
    document.querySelectorAll('.filter-btn').forEach(btn => btn.classList.remove('active'));
    document.querySelector(`[data-category="${category}"]`).classList.add('active');
    
    // Filter and render challenges
    renderChallenges(category);
}

// Render challenges to the grid
function renderChallenges(filterCategory = 'all') {
    if (!challengesData) return;
    
    const challengeGrid = document.getElementById('challenge-grid');
    challengeGrid.innerHTML = '';
    
    const challenges = filterCategory === 'all' 
        ? challengesData.challenges 
        : challengesData.challenges.filter(challenge => challenge.category === filterCategory);
    
    challenges.forEach(challenge => {
        const challengeCard = createChallengeCard(challenge);
        challengeGrid.appendChild(challengeCard);
    });
    
    if (challenges.length === 0) {
        challengeGrid.innerHTML = '<div class="no-challenges">No challenges found in this category.</div>';
    }
}

// Create a challenge card element
function createChallengeCard(challenge) {
    const isSolved = isChallengeSolved(challenge.id);
    const isLocked = !arePrerequisitesMet(challenge.prerequisites);
    
    const card = document.createElement('div');
    card.className = `challenge-card ${isSolved ? 'solved' : ''} ${isLocked ? 'locked' : ''}`;
    card.dataset.challengeId = challenge.id;
    
    card.innerHTML = `
        <div class="challenge-content">
            <div class="challenge-icon">
                <i class="${isLocked ? 'fas fa-lock' : challenge.icon}"></i>
            </div>
            <h3>${challenge.title}</h3>
            <p class="challenge-description-preview">${isLocked ? 'Complete prerequisites to unlock this challenge.' : truncateText(challenge.description, 100)}</p>
        </div>
        <div class="challenge-footer">
            <div class="challenge-meta">
                <span class="badge category-badge">${challenge.category}</span>
                <span class="badge difficulty-badge difficulty-${challenge.difficulty}">${capitalize(challenge.difficulty)}</span>
                <span class="badge points-badge">${challenge.points} pts</span>
            </div>
            <div class="challenge-status">
                ${isSolved ? '<i class="fas fa-check-circle solved-icon"></i> Solved' : 
                  isLocked ? '<i class="fas fa-lock locked-icon"></i> Locked' : 'Unsolved'}
            </div>
            <div class="challenge-actions">
                <button class="btn-small ${isLocked ? 'disabled' : ''}" onclick="${isLocked ? '' : `openChallengeDetail(${challenge.id})`}" ${isLocked ? 'disabled' : ''}">
                    ${isLocked ? 'Locked' : 'View Details'}
                </button>
                ${challenge.files && challenge.files.length > 0 ? '<span class="file-indicator"><i class="fas fa-paperclip"></i></span>' : ''}
            </div>
        </div>
    `;
    
    // Add hover effects
    card.addEventListener('mouseenter', function() {
        this.style.transform = 'translateY(-5px)';
    });
    
    card.addEventListener('mouseleave', function() {
        this.style.transform = 'translateY(0)';
    });
    
    return card;
}

// Open challenge detail modal
function openChallengeDetail(challengeId) {
    const challenge = challengesData.challenges.find(c => c.id === challengeId);
    if (!challenge) return;
    
    // Check if challenge is locked
    if (!arePrerequisitesMet(challenge.prerequisites)) {
        showLockedChallengeMessage(challenge);
        return;
    }
    
    currentChallenge = challenge;
    populateChallengeModal(challenge);
    openModal('challenge-modal');
}

// Populate the challenge modal with data
function populateChallengeModal(challenge) {
    // Basic information
    document.getElementById('modal-icon').className = challenge.icon;
    document.getElementById('modal-title').textContent = challenge.title;
    document.getElementById('modal-category').textContent = challenge.category;
    document.getElementById('modal-difficulty').textContent = capitalize(challenge.difficulty);
    document.getElementById('modal-difficulty').className = `badge difficulty-badge difficulty-${challenge.difficulty}`;
    document.getElementById('modal-points').textContent = `${challenge.points} pts`;
    
    // Description (support markdown-like formatting)
    document.getElementById('modal-description').innerHTML = formatDescription(challenge.description);
    
    // Connection information
    const connectionSection = document.getElementById('modal-connection-section');
    if (challenge.connection_info) {
        document.getElementById('modal-connection').textContent = challenge.connection_info;
        connectionSection.style.display = 'block';
    } else {
        connectionSection.style.display = 'none';
    }
    
    // Files
    const filesSection = document.getElementById('modal-files-section');
    if (challenge.files && challenge.files.length > 0) {
        renderChallengeFiles(challenge.files);
        filesSection.style.display = 'block';
    } else {
        filesSection.style.display = 'none';
    }
    
    // Prerequisites
    const prerequisitesSection = document.getElementById('modal-prerequisites-section');
    if (challenge.prerequisites && challenge.prerequisites.length > 0) {
        renderPrerequisites(challenge.prerequisites);
        prerequisitesSection.style.display = 'block';
    } else {
        prerequisitesSection.style.display = 'none';
    }
    
    // Hints
    const hintsSection = document.getElementById('modal-hints-section');
    if (challenge.hints && challenge.hints.length > 0) {
        renderHints(challenge.hints);
        hintsSection.style.display = 'block';
    } else {
        hintsSection.style.display = 'none';
    }
    
    // Reset flag input
    const flagInput = document.getElementById('flag-input');
    const submitBtn = document.getElementById('submit-flag-btn');
    const flagResult = document.getElementById('flag-result');
    
    flagInput.value = '';
    flagResult.innerHTML = '';
    
    // Check if already solved and disable input/button if so
    const isSolved = isChallengeSolved(challenge.id);
    if (isSolved) {
        flagInput.disabled = true;
        flagInput.placeholder = 'Challenge already solved';
        submitBtn.disabled = true;
        submitBtn.classList.add('disabled');
        flagResult.innerHTML = '<div class="flag-success"><i class="fas fa-check-circle"></i> Challenge already solved! No additional points can be earned.</div>';
    } else {
        flagInput.disabled = false;
        flagInput.placeholder = 'Enter flag here...';
        submitBtn.disabled = false;
        submitBtn.classList.remove('disabled');
    }
}

// Render challenge files
function renderChallengeFiles(files) {
    const filesContainer = document.getElementById('modal-files');
    filesContainer.innerHTML = files.map(file => `
        <div class="file-item">
            <div class="file-info">
                <i class="fas fa-file"></i>
                <span class="file-name">${file.name}</span>
                <span class="file-type">(${file.type})</span>
            </div>
            <div class="file-description">${file.description}</div>
            <a href="${file.download_url}" download class="btn-small file-download">
                <i class="fas fa-download"></i> Download
            </a>
        </div>
    `).join('');
}

// Render prerequisites
function renderPrerequisites(prerequisites) {
    const prerequisitesContainer = document.getElementById('modal-prerequisites');
    const prerequisiteItems = prerequisites.map(id => {
        const prereqChallenge = challengesData.challenges.find(c => c.id === id);
        const challengeName = prereqChallenge ? prereqChallenge.title : `Challenge ${id}`;
        const isCompleted = isChallengeSolved(id);
        
        return {
            name: challengeName,
            completed: isCompleted
        };
    });
    
    prerequisitesContainer.innerHTML = `
        <div class="prerequisites-list">
            ${prerequisiteItems.map(item => `
                <span class="prerequisite-item ${item.completed ? 'completed' : 'pending'}">
                    <i class="fas fa-${item.completed ? 'check-circle' : 'clock'}"></i>
                    ${item.name}
                </span>
            `).join('')}
        </div>
    `;
}

// Render hints with dropdown functionality
function renderHints(hints) {
    const hintsContainer = document.getElementById('modal-hints');
    hintsContainer.innerHTML = hints.map((hint, index) => `
        <div class="hint-item">
            <div class="hint-header" onclick="toggleHint(${index})">
                <span class="hint-title">Hint ${index + 1}</span>
                <i class="fas fa-chevron-down hint-chevron" id="hint-chevron-${index}"></i>
            </div>
            <div class="hint-content" id="hint-content-${index}" style="display: none;">
                ${hint.content}
            </div>
        </div>
    `).join('');
}

// Toggle hint dropdown
function toggleHint(index) {
    const content = document.getElementById(`hint-content-${index}`);
    const chevron = document.getElementById(`hint-chevron-${index}`);
    
    if (content.style.display === 'none') {
        content.style.display = 'block';
        chevron.style.transform = 'rotate(180deg)';
    } else {
        content.style.display = 'none';
        chevron.style.transform = 'rotate(0deg)';
    }
}

// Setup event listeners
function setupEventListeners() {
    // Flag submission
    document.getElementById('submit-flag-btn').addEventListener('click', submitFlag);
    document.getElementById('flag-input').addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            submitFlag();
        }
    });
}

// Submit flag for verification
function submitFlag() {
    if (!currentChallenge) return;
    
    const flagInput = document.getElementById('flag-input');
    const flagResult = document.getElementById('flag-result');
    const submitBtn = document.getElementById('submit-flag-btn');
    const submittedFlag = flagInput.value.trim();
    
    // Prevent submission if challenge is already solved
    if (isChallengeSolved(currentChallenge.id)) {
        flagResult.innerHTML = '<div class="flag-error">Challenge already solved! No additional points can be earned.</div>';
        return;
    }
    
    if (!submittedFlag) {
        flagResult.innerHTML = '<div class="flag-error">Please enter a flag.</div>';
        return;
    }
    
    // Check against all possible flags for the challenge
    const isCorrect = currentChallenge.flags.some(flag => {
        if (flag.case_sensitive) {
            return submittedFlag === flag.value;
        } else {
            return submittedFlag.toLowerCase() === flag.value.toLowerCase();
        }
    });
    
    if (isCorrect) {
        // Store the submitted flag (only if not already solved)
        if (!isChallengeSolved(currentChallenge.id)) {
            addSolvedChallenge(currentChallenge.id, submittedFlag);
            
            // Update challenge card
            const card = document.querySelector(`[data-challenge-id="${currentChallenge.id}"]`);
            if (card) {
                card.classList.add('solved');
                card.querySelector('.challenge-status').innerHTML = '<i class="fas fa-check-circle solved-icon"></i> Solved';
            }
            
            // Disable flag input and submit button immediately
            flagInput.disabled = true;
            flagInput.placeholder = 'Challenge already solved';
            submitBtn.disabled = true;
            submitBtn.classList.add('disabled');
            
            // Re-render challenges to update locked/unlocked states
            setTimeout(() => {
                renderChallenges();
            }, 500); // Small delay to let user see the success message
        }
        
        flagResult.innerHTML = `
            <div class="flag-success">
                <i class="fas fa-check-circle"></i> 
                Correct! You earned ${currentChallenge.points} points!
            </div>
        `;
        flagInput.value = '';
    } else {
        flagResult.innerHTML = '<div class="flag-error"><i class="fas fa-times-circle"></i> Incorrect flag. Try again!</div>';
    }
}

// Check if a challenge is solved by validating the stored flag
function isChallengeSolved(challengeId) {
    if (!challengesData) {
        return false;
    }
    
    const solvedChallenges = getSolvedChallenges();
    const solvedEntry = solvedChallenges.find(([id, _]) => id == challengeId);
    
    if (!solvedEntry) {
        return false;
    }
    
    const [_, submittedFlag] = solvedEntry;
    const challenge = challengesData.challenges.find(c => c.id === challengeId);
    
    if (!challenge) {
        return false;
    }
    
    // Check if the submitted flag matches any valid flag for this challenge
    return challenge.flags.some(flag => {
        if (flag.case_sensitive) {
            return submittedFlag === flag.value;
        } else {
            return submittedFlag.toLowerCase() === flag.value.toLowerCase();
        }
    });
}

// Check if prerequisites are met for a challenge
function arePrerequisitesMet(prerequisites) {
    if (!prerequisites || prerequisites.length === 0) {
        return true; // No prerequisites means always unlocked
    }
    
    // Check if all prerequisite challenge IDs are solved (have valid flags)
    return prerequisites.every(prereqId => isChallengeSolved(prereqId));
}

// Get prerequisite challenge names
function getPrerequisiteNames(prerequisites) {
    if (!prerequisites || prerequisites.length === 0) {
        return [];
    }
    
    return prerequisites.map(id => {
        const challenge = challengesData.challenges.find(c => c.id === id);
        return challenge ? challenge.title : `Challenge ${id}`;
    });
}

// Utility functions
function truncateText(text, maxLength) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength) + '...';
}

function capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1);
}

function formatDescription(description) {
    // Simple markdown-like formatting with code block support
    return description
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
        .replace(/\*(.*?)\*/g, '<em>$1</em>')
        .replace(/<code>([\s\S]*?)<\/code>/g, function(match, code) {
            // Try to detect and format JSON
            const trimmedCode = code.trim();
            let formattedCode = trimmedCode;
            let isJson = false;
            
            // Check if it looks like JSON
            if ((trimmedCode.startsWith('{') && trimmedCode.endsWith('}')) || 
                (trimmedCode.startsWith('[') && trimmedCode.endsWith(']'))) {
                try {
                    const parsed = JSON.parse(trimmedCode);
                    formattedCode = JSON.stringify(parsed, null, 2);
                    isJson = true;
                } catch (e) {
                    // If parsing fails, keep original formatting
                    formattedCode = trimmedCode;
                }
            }
            
            // Apply syntax highlighting for JSON
            if (isJson) {
                const highlightedCode = highlightJson(formattedCode);
                return `<div class="code-block json-code">
                    <button class="copy-button" onclick="copyToClipboard('${escapeForJs(formattedCode)}')">Copy</button>
                    <pre><code>${highlightedCode}</code></pre>
                </div>`;
            } else {
                return `<div class="code-block">
                    <button class="copy-button" onclick="copyToClipboard('${escapeForJs(formattedCode)}')">Copy</button>
                    <pre><code>${escapeHtml(formattedCode)}</code></pre>
                </div>`;
            }
        })
        .replace(/\n/g, '<br>');
}

// Helper function to escape HTML characters
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// JSON syntax highlighting function
function highlightJson(jsonString) {
    return jsonString
        .replace(/(".*?")\s*:/g, '<span class="json-key">$1</span>:')
        .replace(/:\s*(".*?")/g, ': <span class="json-string">$1</span>')
        .replace(/:\s*(true|false|null)/g, ': <span class="json-literal">$1</span>')
        .replace(/:\s*(-?\d+\.?\d*)/g, ': <span class="json-number">$1</span>')
        .replace(/([{}[\],])/g, '<span class="json-punctuation">$1</span>');
}

// Helper function to escape strings for JavaScript attributes
function escapeForJs(text) {
    return text.replace(/'/g, "\\'").replace(/"/g, '\\"').replace(/\n/g, '\\n').replace(/\r/g, '\\r');
}

// Copy to clipboard function
function copyToClipboard(text) {
    navigator.clipboard.writeText(text).then(function() {
        // Show a temporary success message
        showCopySuccess();
    }).catch(function(err) {
        console.error('Failed to copy text: ', err);
        // Fallback for older browsers
        const textArea = document.createElement('textarea');
        textArea.value = text;
        document.body.appendChild(textArea);
        textArea.select();
        try {
            document.execCommand('copy');
            showCopySuccess();
        } catch (err) {
            console.error('Fallback copy failed: ', err);
        }
        document.body.removeChild(textArea);
    });
}

// Show copy success notification
function showCopySuccess() {
    // Create a temporary notification
    const notification = document.createElement('div');
    notification.textContent = 'Copied to clipboard!';
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: var(--success-color);
        color: white;
        padding: 10px 15px;
        border-radius: 5px;
        z-index: 10000;
        font-size: 14px;
        box-shadow: 0 2px 5px rgba(0,0,0,0.2);
    `;
    document.body.appendChild(notification);
    
    // Remove after 2 seconds
    setTimeout(() => {
        document.body.removeChild(notification);
    }, 2000);
}

function showError(message) {
    const challengeGrid = document.getElementById('challenge-grid');
    challengeGrid.innerHTML = `<div class="error-message">${message}</div>`;
}

// Show locked challenge message
function showLockedChallengeMessage(challenge) {
    const prerequisiteNames = getPrerequisiteNames(challenge.prerequisites);
    const prerequisiteList = prerequisiteNames.join(', ');
    
    alert(`🔒 Challenge Locked!\n\n"${challenge.title}" requires you to complete the following challenges first:\n\n${prerequisiteList}\n\nComplete these challenges to unlock "${challenge.title}".`);
}

// Modal functions
function openModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.style.display = 'block';
        document.body.style.overflow = 'hidden';
    }
}

function closeModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.style.display = 'none';
        document.body.style.overflow = '';
    }
}

// Close modal when clicking outside
window.addEventListener('click', function(event) {
    const modals = document.getElementsByClassName('modal');
    for (let i = 0; i < modals.length; i++) {
        if (event.target === modals[i]) {
            modals[i].style.display = 'none';
            document.body.style.overflow = '';
        }
    }
});

// Function to check the status of all challenges (disabled - no port configuration)
/*
function checkAllChallengeStatus() {
    // This function is disabled as challenges don't have port configuration
    console.log('Challenge status checking is disabled');
}
*/

// Function to check if a service is online (disabled)
/*
function checkServiceStatus(url) {
    return new Promise((resolve) => {
        const timeout = 2000; // 2 seconds timeout
        const startTime = Date.now();
        
        // Create a fetch request with timeout
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), timeout);
        
        fetch(url, { 
            method: 'HEAD',
            signal: controller.signal,
            mode: 'no-cors' // This is needed for CORS issues
        })
        .then(() => {
            clearTimeout(timeoutId);
            resolve(true);
        })
        .catch(() => {
            clearTimeout(timeoutId);
            resolve(false);
        });
    });
}
*/

// Add CSS class for disabled buttons
document.addEventListener('DOMContentLoaded', function() {
    const style = document.createElement('style');
    style.textContent = `
        .btn-small.disabled {
            background-color: #95a5a6;
            cursor: not-allowed;
            pointer-events: none;
        }
    `;
    document.head.appendChild(style);
}); 