const SUITS = ['♠', '♥', '♣', '♦'];
const RANKS = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
const WHITE_CARD_COUNT = 10;
const WHITE_CARD_RANK = '白';
const WHITE_CARD_SUIT = '□';

const CHAMELEON_HEART = { rank: '变', suit: '♥', color: 'red', type: 'chameleon' };
const CHAMELEON_SPADE = { rank: '变', suit: '♠', color: 'black', type: 'chameleon' };
const CHAMELEON_DIAMOND = { rank: '变', suit: '♦', color: 'red', type: 'chameleon' };
const CHAMELEON_CLUB = { rank: '变', suit: '♣', color: 'black', type: 'chameleon' };

const ITEM_PRICES = {
    'white': 3,
    'chameleon': 5
};

const MIN_HAND_QUEUE_SIZE = 9;
const MAX_HAND_QUEUE_SIZE = 20;
const DEFAULT_HAND_QUEUE_SIZE = 15;
const HAND_SIZE_STORAGE_KEY = 'fifocard_hand_queue_size';


function clampHandQueueSize(size) {
    return Math.min(MAX_HAND_QUEUE_SIZE, Math.max(MIN_HAND_QUEUE_SIZE, size));
}

function getSavedHandQueueSize() {
    const savedValue = Number(localStorage.getItem(HAND_SIZE_STORAGE_KEY));
    if (!Number.isInteger(savedValue)) return DEFAULT_HAND_QUEUE_SIZE;
    return clampHandQueueSize(savedValue);
}

let currentHandQueueSize = getSavedHandQueueSize();

function getLevelTargetScore(level) {
    return 1000 * Math.pow(level, 2);
}


function isWhiteCard(card) {
    return !!card && card.rank === WHITE_CARD_RANK && card.suit === WHITE_CARD_SUIT;
}

// Card values
const getCardValue = (rank) => {
    if (rank === WHITE_CARD_RANK) return 0;
    if (rank === 'A') return 11;
    if (rank === 'J') return 10;
    if (rank === 'Q') return 10;
    if (rank === 'K') return 10;
    return parseInt(rank, 10);
};


// State
let deck = [];
let itemDeck = [];
let shopCards = [];
let itemSlots = [null, null];
let handQueue = [];
let activeCard = null;
let score = 0;
let highScore = localStorage.getItem('fifocard_highscore') ? parseInt(localStorage.getItem('fifocard_highscore')) : 0;
let isNewRecord = false;
let currentLevel = 1;
let levelTargetScore = getLevelTargetScore(currentLevel);
let gold = 4;
let isProcessing = false; // Lock interaction during animations/combos
let cardIdCounter = 0;
let knownCardIds = new Set();
let isDrawingPhase = false;
let playAreaCards = [];
let playAreaGroups = [];
let isAwaitingRoundConfirm = false;
let pendingWhiteReturns = [];
let selectedActiveSource = 'active'; // 'active', 'item0', 'item1'
let draggingCardSource = null;
let isRankSortPreviewing = false;

let isDebugMode = false;
let debugContinueResolver = null;

// Chain Combo state
let initialScore = 0;
let chainCardsCount = 0;
let chainValueSum = 0;

// DOM Elements
const handContainer = document.getElementById('hand-container');
const playAreaContainer = document.getElementById('play-area-container');
const activeCardContainer = document.getElementById('active-card-container');
const scoreDisplay = document.getElementById('score-display');
const highScoreDisplay = document.getElementById('highscore-display');
const levelDisplay = document.getElementById('level-display');
const targetScoreDisplay = document.getElementById('target-score-display');
const deckDisplay = document.getElementById('deck-display');
const gameOverModal = document.getElementById('game-over-modal');
const finalScoreDisplay = document.getElementById('final-score');
const restartBtn = document.getElementById('restart-btn');
const comboBadge = document.getElementById('combo-badge');
const handSizeSelect = document.getElementById('hand-size-select');
const dropTailBtn = document.getElementById('drop-tail-btn');
const confirmRoundBtn = document.getElementById('confirm-round-btn');
const selectActiveBtn = document.getElementById('select-active-btn');
const goldDisplay = document.getElementById('gold-display');
const levelClearModal = document.getElementById('level-clear-modal');
const lcCurrentGold = document.getElementById('lc-current-gold');
const lcInterest = document.getElementById('lc-interest');
const lcReward = document.getElementById('lc-reward');
const lcTotalGold = document.getElementById('lc-total-gold');
const nextLevelBtn = document.getElementById('next-level-btn');
const debugModeToggle = document.getElementById('debug-mode-toggle');
const debugContinueBtn = document.getElementById('debug-continue-btn');
const nextCardPreviewContainer = document.getElementById('next-card-preview-container');
const rankSortPreviewBtn = document.getElementById('rank-sort-preview-btn');

// Item Slots
const itemSlot0Container = document.getElementById('item-slot-0-container');
const useItem0Btn = document.getElementById('use-item-0-btn');
const itemSlot1Container = document.getElementById('item-slot-1-container');
const useItem1Btn = document.getElementById('use-item-1-btn');

// Shop Modal
const shopModal = document.getElementById('shop-modal');
const shopCardsContainer = document.getElementById('shop-cards-container');
const closeShopBtn = document.getElementById('close-shop-btn');


function syncHandSizeControl() {
    if (handSizeSelect) {
        handSizeSelect.value = String(currentHandQueueSize);
    }
}

function setHandQueueSize(size) {
    if (!Number.isInteger(size)) return;
    currentHandQueueSize = clampHandQueueSize(size);
    localStorage.setItem(HAND_SIZE_STORAGE_KEY, String(currentHandQueueSize));
    syncHandSizeControl();
}

function setConfirmButtonState(enabled) {
    if (!confirmRoundBtn) return;
    confirmRoundBtn.disabled = !enabled;
}

function getRankSortOrder(card) {
    if (!card) return Number.MAX_SAFE_INTEGER;
    if (card.rank === WHITE_CARD_RANK) return 0;
    const orderMap = {
        'A': 1,
        '2': 2,
        '3': 3,
        '4': 4,
        '5': 5,
        '6': 6,
        '7': 7,
        '8': 8,
        '9': 9,
        '10': 10,
        'J': 11,
        'Q': 12,
        'K': 13
    };
    return orderMap[card.rank] ?? 99;
}

function getDisplayHandQueue() {
    if (!isRankSortPreviewing) return handQueue;
    return handQueue
        .map((card, index) => ({ card, index }))
        .sort((a, b) => {
            const rankDiff = getRankSortOrder(a.card) - getRankSortOrder(b.card);
            if (rankDiff !== 0) return rankDiff;
            return a.index - b.index;
        })
        .map(item => item.card);
}

function setRankSortPreviewing(enabled) {
    const nextState = Boolean(enabled) && !isProcessing && !isAwaitingRoundConfirm;
    if (isRankSortPreviewing === nextState) return;
    isRankSortPreviewing = nextState;
    updateUI();
}

function hasItemCard(index) {
    return !!itemSlots[index];
}

function getCardBySource(source) {
    if (source === 'item0') {
        return itemSlots[0];
    }
    if (source === 'item1') {
        return itemSlots[1];
    }
    return activeCard;
}

function getCurrentSelectedCard() {
    if (draggingCardSource) {
        const draggingCard = getCardBySource(draggingCardSource);
        if (draggingCard) return draggingCard;
    }
    if (selectedActiveSource === 'item0' && itemSlots[0]) {
        return itemSlots[0];
    }
    if (selectedActiveSource === 'item1' && itemSlots[1]) {
        return itemSlots[1];
    }
    return activeCard;
}


function setSelectedActiveSource(source) {
    if (source === 'item0' && !itemSlots[0]) {
        selectedActiveSource = 'active';
        return;
    }
    if (source === 'item1' && !itemSlots[1]) {
        selectedActiveSource = 'active';
        return;
    }
    if (source === 'item0' || source === 'item1') {
        selectedActiveSource = source;
    } else {
        selectedActiveSource = 'active';
    }
}

function startNextLevel() {
    currentLevel++;
    levelTargetScore = getLevelTargetScore(currentLevel);
    score = 0;
    initGame(false);
}

// Initialize Game
function initGame(resetProgress = true) {
    deck = [];
    handQueue = [];
    selectedActiveSource = 'active';
    isRankSortPreviewing = false;
    shopCards = [];
    if (resetProgress) {
        itemSlots = [null, null];
        score = 0;
        currentLevel = 1;
        levelTargetScore = getLevelTargetScore(currentLevel);
        gold = 4;
        isNewRecord = false;
        
        itemDeck = [];
        for (let i = 0; i < WHITE_CARD_COUNT; i++) {
            itemDeck.push({
                id: cardIdCounter++,
                suit: WHITE_CARD_SUIT,
                rank: WHITE_CARD_RANK,
                value: 0,
                color: 'white',
                type: 'white'
            });
        }
        for(let i=0; i<2; i++) {
            itemDeck.push({ id: cardIdCounter++, ...CHAMELEON_HEART });
            itemDeck.push({ id: cardIdCounter++, ...CHAMELEON_SPADE });
            itemDeck.push({ id: cardIdCounter++, ...CHAMELEON_DIAMOND });
            itemDeck.push({ id: cardIdCounter++, ...CHAMELEON_CLUB });
        }
        for (let i = itemDeck.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [itemDeck[i], itemDeck[j]] = [itemDeck[j], itemDeck[i]];
        }
    }
    initialScore = score;
    chainCardsCount = 0;
    chainValueSum = 0;
    isProcessing = false;
    knownCardIds.clear();
    isDrawingPhase = false;
    playAreaCards = [];
    playAreaGroups = [];
    isAwaitingRoundConfirm = false;
    pendingWhiteReturns = [];
    setConfirmButtonState(false);
    
    hideComboBadge();
    
    // Create Deck
    for (let suit of SUITS) {
        for (let rank of RANKS) {
            deck.push({
                id: cardIdCounter++,
                suit,
                rank,
                value: getCardValue(rank),
                color: (suit === '♥' || suit === '♦') ? 'red' : 'black'
            });
        }
    }

    // Shuffle Deck
    for (let i = deck.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [deck[i], deck[j]] = [deck[j], deck[i]];
    }
    
    // 开局先抽“手牌队列 + 激活牌”数量的普通牌
    drawNormalCardToHandQueue(currentHandQueueSize + 1, true);

    // Initial Active Card: 从手牌队列最右侧取一张
    activeCard = handQueue.length > 0 ? handQueue.pop() : null;

    
    updateUI();
    hideGameOver();
}

// Event Listeners
restartBtn.addEventListener('click', initGame);

if (handSizeSelect) {
    handSizeSelect.addEventListener('change', () => {
        setHandQueueSize(Number(handSizeSelect.value));
        initGame();
    });
}

if (debugModeToggle) {
    debugModeToggle.addEventListener('change', (e) => {
        isDebugMode = e.target.checked;
    });
}

if (debugContinueBtn) {
    debugContinueBtn.addEventListener('click', () => {
        if (debugContinueResolver) {
            debugContinueBtn.classList.add('hidden');
            debugContinueResolver();
            debugContinueResolver = null;
        }
    });
}

syncHandSizeControl();

if (dropTailBtn) {
    dropTailBtn.addEventListener('click', () => {
        if (isProcessing || !getCurrentSelectedCard() || isAwaitingRoundConfirm || isRankSortPreviewing) return;
        handleDrop(0);
    });
}

if (rankSortPreviewBtn) {
    rankSortPreviewBtn.addEventListener('pointerdown', (e) => {
        if (isProcessing || isAwaitingRoundConfirm || handQueue.length === 0) return;
        e.preventDefault();
        setRankSortPreviewing(true);
    });

    rankSortPreviewBtn.addEventListener('pointerup', () => {
        setRankSortPreviewing(false);
    });

    rankSortPreviewBtn.addEventListener('pointerleave', () => {
        setRankSortPreviewing(false);
    });

    rankSortPreviewBtn.addEventListener('pointercancel', () => {
        setRankSortPreviewing(false);
    });

    window.addEventListener('pointerup', () => {
        if (!isRankSortPreviewing) return;
        setRankSortPreviewing(false);
    });
}

if (selectActiveBtn) {
    selectActiveBtn.addEventListener('click', () => {
        if (isProcessing || isAwaitingRoundConfirm || !activeCard) return;
        setSelectedActiveSource('active');
        updateUI();
    });
}

if (useItem0Btn) {
    useItem0Btn.addEventListener('click', () => {
        if (isProcessing || isAwaitingRoundConfirm || !itemSlots[0]) return;
        setSelectedActiveSource('item0');
        updateUI();
    });
}

if (useItem1Btn) {
    useItem1Btn.addEventListener('click', () => {
        if (isProcessing || isAwaitingRoundConfirm || !itemSlots[1]) return;
        setSelectedActiveSource('item1');
        updateUI();
    });
}

if (confirmRoundBtn) {
    confirmRoundBtn.addEventListener('click', () => {
        if (isProcessing || !isAwaitingRoundConfirm) return;
        confirmRoundSettlement();
    });
}


handContainer.addEventListener('dragover', (e) => {
    if (isProcessing || isAwaitingRoundConfirm || isRankSortPreviewing) return;
    e.preventDefault(); // allow drop on the entire container
    
    const index = getDragAfterIndex(e.clientX);
    checkMatchHighlight(index);

    // Highlight the nearest drop zone
    document.querySelectorAll('.drop-zone').forEach((el, i) => {
        if (i === index) {
            el.classList.add('drag-over');
        } else {
            el.classList.remove('drag-over');
        }
    });
});

handContainer.addEventListener('dragleave', (e) => {
    if (isProcessing || isAwaitingRoundConfirm || isRankSortPreviewing) return;
    // clear highlight when leaving the entire hand container
    if (!handContainer.contains(e.relatedTarget)) {
        clearHighlights();
        document.querySelectorAll('.drop-zone').forEach(el => el.classList.remove('drag-over'));
    }
});

handContainer.addEventListener('drop', (e) => {
    if (isProcessing || isAwaitingRoundConfirm || isRankSortPreviewing) return;
    e.preventDefault();
    clearHighlights();
    document.querySelectorAll('.drop-zone').forEach(el => el.classList.remove('drag-over'));

    const dragSource = e.dataTransfer ? e.dataTransfer.getData('text/plain') : '';
    const normalizedSource = ['item0', 'item1', 'active'].includes(dragSource) ? dragSource : draggingCardSource;
    const index = getDragAfterIndex(e.clientX);
    handleDrop(index, normalizedSource);
    draggingCardSource = null;
});


function getDragAfterIndex(clientX) {
    const cardEls = [...handContainer.querySelectorAll('.playing-card:not(.dragging)')];
    
    // Find the first card whose center is to the right of the mouse cursor
    for (let i = 0; i < cardEls.length; i++) {
        const box = cardEls[i].getBoundingClientRect();
        const center = box.left + box.width / 2;
        if (clientX < center) {
            return i;
        }
    }
    return cardEls.length;
}

// Render UI
function updateUI() {
    if ((isProcessing || isAwaitingRoundConfirm) && isRankSortPreviewing) {
        isRankSortPreviewing = false;
    }

    // 1. FLIP: First
    const firstRects = {};
    document.querySelectorAll('.playing-card').forEach(el => {
        if (el.dataset.cardId) {
            firstRects[el.dataset.cardId] = el.getBoundingClientRect();
        }
    });

    // update stats
    scoreDisplay.innerText = score;
    if (goldDisplay) goldDisplay.innerText = gold;
    if (highScoreDisplay) highScoreDisplay.innerText = highScore;
    if (levelDisplay) levelDisplay.innerText = currentLevel;
    if (targetScoreDisplay) targetScoreDisplay.innerText = levelTargetScore;
    deckDisplay.innerText = deck.length;

    if (rankSortPreviewBtn) {
        const previewDisabled = isProcessing || isAwaitingRoundConfirm || handQueue.length === 0;
        rankSortPreviewBtn.disabled = previewDisabled;
        rankSortPreviewBtn.classList.toggle('is-active', isRankSortPreviewing);
    }
    
    // clear container
    handContainer.innerHTML = '';
    if (playAreaContainer) playAreaContainer.innerHTML = '';
    
    // render drop zone 0 (leftmost)
    handContainer.appendChild(createDropZone(0));
    
    // render handQueue
    const displayHandQueue = getDisplayHandQueue();
    displayHandQueue.forEach((card, index) => {
        if (card.isPlaceholder) {
            const placeholder = document.createElement('div');
            placeholder.style.width = '60px';
            placeholder.style.height = '90px';
            placeholder.style.flexShrink = '0';
            handContainer.appendChild(placeholder);
            // empty drop zone for placeholder gap
            const emptyZone = document.createElement('div');
            emptyZone.style.width = '20px';
            handContainer.appendChild(emptyZone);
        } else {
            handContainer.appendChild(createCardElement(card));
            handContainer.appendChild(createDropZone(index + 1));
        }
    });

    // render playAreaCards
    if (playAreaContainer) {
        if (playAreaGroups.length > 0) {
            const groupedIds = new Set();
            playAreaGroups.forEach(group => {
                const groupEl = document.createElement('div');
                groupEl.className = 'play-hand-group';

                const titleEl = document.createElement('div');
                titleEl.className = 'play-hand-title';
                titleEl.innerText = group.name;
                groupEl.appendChild(titleEl);

                const cardsEl = document.createElement('div');
                cardsEl.className = 'play-hand-cards';
                group.cards.forEach(card => {
                    groupedIds.add(card.id);
                    cardsEl.appendChild(createCardElement(card, ['play-card-highlight']));
                });
                groupEl.appendChild(cardsEl);
                playAreaContainer.appendChild(groupEl);
            });

            const ungrouped = playAreaCards.filter(card => !groupedIds.has(card.id));
            if (ungrouped.length > 0) {
                const ungroupedEl = document.createElement('div');
                ungroupedEl.className = 'play-ungrouped';
                ungrouped.forEach(card => {
                    ungroupedEl.appendChild(createCardElement(card));
                });
                playAreaContainer.appendChild(ungroupedEl);
            }
        } else {
            playAreaCards.forEach(card => {
                playAreaContainer.appendChild(createCardElement(card));
            });
        }
    }
    
    // render activeCard
    activeCardContainer.innerHTML = '';
    if (activeCard) {
        const activeEl = createCardElement(activeCard);
        activeEl.draggable = true;
        activeEl.addEventListener('dragstart', (e) => {
            if (isProcessing || isRankSortPreviewing) return e.preventDefault();
            draggingCardSource = 'active';
            e.dataTransfer.setData('text/plain', 'active');
            setTimeout(() => activeEl.classList.add('dragging'), 0);
        });
        activeEl.addEventListener('dragend', () => {
            draggingCardSource = null;
            activeEl.classList.remove('dragging');
            clearHighlights();
        });
        activeCardContainer.appendChild(activeEl);
    }

    // render item slots
    for (let i = 0; i < 2; i++) {
        const container = i === 0 ? itemSlot0Container : itemSlot1Container;
        const itemCard = itemSlots[i];
        if (container) {
            container.innerHTML = '';
            if (itemCard) {
                const itemEl = createCardElement(itemCard);
                itemEl.draggable = true;
                itemEl.addEventListener('dragstart', (e) => {
                    if (isProcessing || isRankSortPreviewing) return e.preventDefault();
                    draggingCardSource = `item${i}`;
                    e.dataTransfer.setData('text/plain', `item${i}`);
                    setTimeout(() => itemEl.classList.add('dragging'), 0);
                });
                itemEl.addEventListener('dragend', () => {
                    draggingCardSource = null;
                    itemEl.classList.remove('dragging');
                    clearHighlights();
                });
                container.appendChild(itemEl);
            }
        }
    }

    const hasItem0 = hasItemCard(0);
    const hasItem1 = hasItemCard(1);

    if (!activeCard) {
        if (hasItem0 && selectedActiveSource !== 'item1') {
            setSelectedActiveSource('item0');
        } else if (hasItem1 && selectedActiveSource !== 'item0') {
            setSelectedActiveSource('item1');
        }
    }
    
    if (!hasItem0 && selectedActiveSource === 'item0') {
        setSelectedActiveSource(hasItem1 ? 'item1' : 'active');
    }
    if (!hasItem1 && selectedActiveSource === 'item1') {
        setSelectedActiveSource(hasItem0 ? 'item0' : 'active');
    }

    if (useItem0Btn) {
        useItem0Btn.disabled = !hasItem0 || isProcessing || isAwaitingRoundConfirm;
        useItem0Btn.className = useItem0Btn.disabled
            ? 'px-3 py-1 rounded-md bg-gray-200 text-gray-500 text-xs font-semibold transition-colors w-full'
            : 'px-3 py-1 rounded-md bg-amber-100 text-amber-700 text-xs font-semibold hover:bg-amber-200 transition-colors w-full';
    }
    
    if (useItem1Btn) {
        useItem1Btn.disabled = !hasItem1 || isProcessing || isAwaitingRoundConfirm;
        useItem1Btn.className = useItem1Btn.disabled
            ? 'px-3 py-1 rounded-md bg-gray-200 text-gray-500 text-xs font-semibold transition-colors w-full'
            : 'px-3 py-1 rounded-md bg-amber-100 text-amber-700 text-xs font-semibold hover:bg-amber-200 transition-colors w-full';
    }

    if (selectActiveBtn) {
        selectActiveBtn.disabled = !activeCard || isProcessing || isAwaitingRoundConfirm;
    }
    
    if (activeCardContainer) {
        activeCardContainer.classList.toggle('selected', selectedActiveSource === 'active');
    }
    
    if (itemSlot0Container) {
        itemSlot0Container.classList.toggle('selected', selectedActiveSource === 'item0' && hasItem0);
    }
    
    if (itemSlot1Container) {
        itemSlot1Container.classList.toggle('selected', selectedActiveSource === 'item1' && hasItem1);
    }

    // render next card preview
    if (nextCardPreviewContainer) {
        nextCardPreviewContainer.innerHTML = '';
        if (deck.length > 0) {
            const nextCard = deck[deck.length - 1];
            const wasKnown = knownCardIds.has(nextCard.id);
            
            const previewEl = createCardElement(nextCard);
            previewEl.classList.remove('anim-enter', 'anim-draw');
            previewEl.draggable = false;
            previewEl.style.pointerEvents = 'none';
            
            if (!wasKnown) {
                knownCardIds.delete(nextCard.id);
            }
            
            nextCardPreviewContainer.appendChild(previewEl);
        }
    }

    // 2. FLIP: Last, Invert, Play

    requestAnimationFrame(() => {
        document.querySelectorAll('.playing-card').forEach(el => {
            const cardId = el.dataset.cardId;
            const lastRect = el.getBoundingClientRect();
            const firstRect = firstRects[cardId];

            if (firstRect && !el.classList.contains('anim-draw') && !el.classList.contains('anim-enter')) {
                const dx = firstRect.left - lastRect.left;
                const dy = firstRect.top - lastRect.top;

                if (dx !== 0 || dy !== 0) {
                    // Invert
                    el.style.transform = `translate(${dx}px, ${dy}px)`;
                    el.style.transition = 'none';

                    // Force reflow
                    el.getBoundingClientRect();

                    // Play
                    el.style.transform = '';
                    el.style.transition = ''; // relies on CSS transition
                }
            }
        });
    });
}

// Create DOM element for a card
function createCardElement(card, extraClasses = []) {
    const el = document.createElement('div');
    el.className = `playing-card ${card.color} ${extraClasses.join(' ')}`.trim();
    el.dataset.cardId = card.id;

    if (!knownCardIds.has(card.id)) {
        if (isDrawingPhase) {
            el.classList.add('anim-draw');
        } else {
            el.classList.add('anim-enter');
        }
        knownCardIds.add(card.id);
    }
    
    if (!isWhiteCard(card)) {
        const topEl = document.createElement('div');
        topEl.className = 'card-top';
        topEl.innerHTML = `<span>${card.rank}</span><span>${card.suit}</span>`;

        const centerEl = document.createElement('div');
        centerEl.className = 'card-center';
        centerEl.innerText = card.suit;

        const bottomEl = document.createElement('div');
        bottomEl.className = 'card-bottom';
        bottomEl.innerHTML = `<span>${card.rank}</span><span>${card.suit}</span>`;

        el.appendChild(topEl);
        el.appendChild(centerEl);
        el.appendChild(bottomEl);
    }

    
    return el;
}

// Create DOM element for a drop zone
function createDropZone(index) {
    const el = document.createElement('div');
    el.className = 'drop-zone';
    el.addEventListener('click', () => {
        if (isRankSortPreviewing) return;
        handleDrop(index);
    });
    
    // Drag events are handled by the handContainer parent
    
    return el;
}

function clearHighlights() {
    document.querySelectorAll('.playing-card.highlight-match').forEach(el => {
        el.classList.remove('highlight-match');
    });
}

function areAllSuitCountsBelowThree() {
    const counts = { '♠': 0, '♥': 0, '♣': 0, '♦': 0 };
    let totalNormalCards = 0;

    handQueue.forEach(card => {
        if (!card || card.isPlaceholder || card.type === 'chameleon' || isWhiteCard(card)) return;
        if (counts[card.suit] !== undefined) {
            counts[card.suit]++;
            totalNormalCards++;
        }
    });

    if (activeCard && !activeCard.isPlaceholder && activeCard.type !== 'chameleon' && !isWhiteCard(activeCard)) {
        if (counts[activeCard.suit] !== undefined) {
            counts[activeCard.suit]++;
            totalNormalCards++;
        }
    }

    if (totalNormalCards < 3) return true;

    let chameleonCount = 0;
    if (itemSlots[0] && itemSlots[0].type === 'chameleon') chameleonCount++;
    if (itemSlots[1] && itemSlots[1].type === 'chameleon') chameleonCount++;
    if (activeCard && activeCard.type === 'chameleon') chameleonCount++;

    let canReachThree = false;
    for (let count of Object.values(counts)) {
        if (count + chameleonCount >= 3) {
            canReachThree = true;
            break;
        }
    }

    return !canReachThree;
}

function shouldCheckEndgameByDeckState() {
    return deck.length === 0;
}


function shouldEndGame() {
    return shouldCheckEndgameByDeckState() && areAllSuitCountsBelowThree();
}

function insertCardToRandomItemDeckPosition(card) {
    const insertIndex = Math.floor(Math.random() * (itemDeck.length + 1));
    itemDeck.splice(insertIndex, 0, card);
}

function drawNormalCardToHandQueue(count, appendToRight = false) {
    let drawnCount = 0;

    while (drawnCount < count && deck.length > 0) {
        const card = deck.pop();

        if (appendToRight) {
            handQueue.push(card);
        } else {
            handQueue.unshift(card);
        }
        drawnCount++;
    }

    return drawnCount;
}



function processPendingWhiteReturn(isTurnAdvance = true) {
    if (!isTurnAdvance) return;

    for (let i = pendingWhiteReturns.length - 1; i >= 0; i--) {
        let pending = pendingWhiteReturns[i];
        if (pending.delay > 0) {
            pending.delay--;
            continue;
        }

        const whiteIndex = handQueue.findIndex(card => card && card.id === pending.id);
        pendingWhiteReturns.splice(i, 1);

        if (whiteIndex >= 0) {
            const [whiteCard] = handQueue.splice(whiteIndex, 1);
            if (whiteCard) {
                insertCardToRandomItemDeckPosition(whiteCard);
                if (pending.drawReplacement) {
                    drawNormalCardToHandQueue(1, false);
                }
            }
        }
    }
}


function getSuitSegment(index) {
    if (index < 0 || index >= handQueue.length) return null;
    const current = handQueue[index];
    if (!current || isWhiteCard(current)) return null;

    const suit = current.suit;
    let start = index;
    let end = index;

    while (start > 0 && !isWhiteCard(handQueue[start - 1]) && handQueue[start - 1].suit === suit) start--;
    while (end < handQueue.length - 1 && !isWhiteCard(handQueue[end + 1]) && handQueue[end + 1].suit === suit) end++;

    const length = end - start + 1;
    if (length < 3) return null;
    return { start, end, length };
}


function getMatchSegment(index) {
    return getSuitSegment(index);
}

function checkMatchHighlight(index) {
    clearHighlights();
    const selectedCard = getCurrentSelectedCard();
    if (!selectedCard || isWhiteCard(selectedCard)) return;

    const previewQueue = [...handQueue];
    previewQueue.splice(index, 0, selectedCard);

    const suit = selectedCard.suit;
    let start = index;
    let end = index;

    while (start > 0 && !isWhiteCard(previewQueue[start - 1]) && previewQueue[start - 1].suit === suit) start--;
    while (end < previewQueue.length - 1 && !isWhiteCard(previewQueue[end + 1]) && previewQueue[end + 1].suit === suit) end++;

    const matchLength = end - start + 1;
    if (matchLength < 3) return;

    const cardEls = handContainer.querySelectorAll('.playing-card');
    for (let i = start; i <= end; i++) {
        if (i === index) continue;
        const handIndex = i > index ? i - 1 : i;
        if (cardEls[handIndex]) {
            cardEls[handIndex].classList.add('highlight-match');
        }
    }

    const selectedContainer = selectedActiveSource === 'item0' ? itemSlot0Container : (selectedActiveSource === 'item1' ? itemSlot1Container : activeCardContainer);
    const selectedEl = selectedContainer ? selectedContainer.querySelector('.playing-card') : null;
    if (selectedEl) {
        selectedEl.classList.add('highlight-match');
    }
}



async function handleDrop(index, forcedSource = null) {
    const validSources = ['item0', 'item1', 'active'];
    const cardSource = validSources.includes(forcedSource) ? forcedSource : selectedActiveSource;
    const selectedCard = getCardBySource(cardSource) || getCurrentSelectedCard();
    if (isProcessing || !selectedCard || isAwaitingRoundConfirm || isRankSortPreviewing) return;
    
    // 变色龙如果插在最左边（index === 0），或者左侧是白牌，直接视为无效，回弹到卡槽
    if (selectedCard.type === 'chameleon' && (index === 0 || isWhiteCard(handQueue[index - 1]))) {
        updateUI(); // just clear highlights/drag
        return;
    }
    
    isProcessing = true;

    // Reset chain counters for the new drop
    initialScore = score;
    chainCardsCount = 0;
    chainValueSum = 0;
    hideComboBadge();
    playAreaGroups = [];

    // Chameleon logic: change left card color
    if (selectedCard.type === 'chameleon') {
        const leftCard = handQueue[index - 1];
        if (leftCard && !isWhiteCard(leftCard)) {
            leftCard.suit = selectedCard.suit;
            leftCard.color = selectedCard.color;
        }
        
        // Remove from slot, put back to itemDeck
        if (cardSource === 'item0') {
            itemSlots[0] = null;
        } else if (cardSource === 'item1') {
            itemSlots[1] = null;
        } else {
            activeCard = null;
        }
        itemDeck.push(selectedCard);
        
        setSelectedActiveSource('active');
        updateUI();
        await sleep(300);

        await advanceRoundAfterSettlement(cardSource === 'active');
        isProcessing = false;
        return;
    }

    // Insert selected card at index
    const insertedCard = selectedCard;
    handQueue.splice(index, 0, insertedCard);
    
    if (cardSource === 'item0') {
        itemSlots[0] = null;
        setSelectedActiveSource('active');
    } else if (cardSource === 'item1') {
        itemSlots[1] = null;
        setSelectedActiveSource('active');
    } else {
        activeCard = null;
    }

    updateUI();
    await sleep(300);


    const isTurnAdvance = cardSource === 'active';

    // 白牌作为激活牌插入时：本操作不消耗回合，本回合不进行消除检测
    if (isWhiteCard(insertedCard)) {
        pendingWhiteReturns.push({
            id: insertedCard.id,
            delay: 0,
            drawReplacement: isTurnAdvance
        });
        await advanceRoundAfterSettlement(isTurnAdvance);
        isProcessing = false;
        return;
    }


    // Initial Match Check around the inserted card
    await checkAndResolveMatches(index);

    if (isAwaitingRoundConfirm) {
        isProcessing = false;
        return;
    }

    await advanceRoundAfterSettlement(isTurnAdvance);
    isProcessing = false;
}


// === Poker Hand Algorithm ===
function getCombinations(array, size) {
    let result = [];
    function backtrack(start, combo) {
        if (combo.length === size) {
            result.push([...combo]);
            return;
        }
        for (let i = start; i < array.length; i++) {
            combo.push(array[i]);
            backtrack(i + 1, combo);
            combo.pop();
        }
    }
    backtrack(0, []);
    return result;
}

function generateCandidateHands(cards) {
    let candidates = [];
    const scoringCards = cards.filter(card => !isWhiteCard(card));
    
    // Assign a unique bit index to each card
    let cardList = scoringCards.map((c, idx) => ({ ...c, bitMap: 1n << BigInt(idx) }));

    
    // Group by rank
    let byRank = {};
    // Group by suit
    let bySuit = {};
    
    cardList.forEach(c => {
        if (!byRank[c.rank]) byRank[c.rank] = [];
        byRank[c.rank].push(c);
        
        if (!bySuit[c.suit]) bySuit[c.suit] = [];
        bySuit[c.suit].push(c);
    });
    
    let ranksPresent = Object.keys(byRank);
    let suitsPresent = Object.keys(bySuit);
    
    function addHand(name, mult, subset) {
        let mask = 0n;
        let sumVal = 0;
        for (let c of subset) {
            mask |= c.bitMap;
            sumVal += c.value;
        }
        let bonus = sumVal * (mult - 1);
        candidates.push({ name, mask, bonus, mult, subset });
    }
    
    // 1. Pair, 2. Three of a kind, 3. Four of a kind
    for (let r of ranksPresent) {
        let group = byRank[r];
        if (group.length >= 2) {
            let pairs = getCombinations(group, 2);
            pairs.forEach(p => addHand("对子", 2, p));
        }
        if (group.length >= 3) {
            let threes = getCombinations(group, 3);
            threes.forEach(t => addHand("三条", 4, t));
        }
        if (group.length === 4) {
            addHand("四条", 10, group);
        }
    }
    
    // 4. Two Pair
    let pairRanks = ranksPresent.filter(r => byRank[r].length >= 2);
    if (pairRanks.length >= 2) {
        let rankPairs = getCombinations(pairRanks, 2);
        for (let rp of rankPairs) {
            let r1 = rp[0], r2 = rp[1];
            let p1s = getCombinations(byRank[r1], 2);
            let p2s = getCombinations(byRank[r2], 2);
            for (let p1 of p1s) {
                for (let p2 of p2s) {
                    addHand("两对", 5, [...p1, ...p2]);
                }
            }
        }
    }
    
    // 5. Full House
    let threeRanks = ranksPresent.filter(r => byRank[r].length >= 3);
    for (let r3 of threeRanks) {
        for (let r2 of pairRanks) {
            if (r3 === r2) continue;
            let t3s = getCombinations(byRank[r3], 3);
            let p2s = getCombinations(byRank[r2], 2);
            for (let t3 of t3s) {
                for (let p2 of p2s) {
                    addHand("葫芦", 7, [...t3, ...p2]);
                }
            }
        }
    }
    
    // 6. Flush
    for (let s of suitsPresent) {
        let group = bySuit[s];
        if (group.length >= 5) {
            let flushes = getCombinations(group, 5);
            flushes.forEach(f => addHand("同花", 6, f));
        }
    }
    
    // 7. Straight & Straight Flush
    const rankOrder = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
    for (let i = 0; i <= 9; i++) {
        let neededRanks = rankOrder.slice(i, i + 5);
        let hasAll = neededRanks.every(r => byRank[r] && byRank[r].length > 0);
        if (hasAll) {
            let ways = [[]];
            for (let r of neededRanks) {
                let newWays = [];
                for (let w of ways) {
                    for (let c of byRank[r]) {
                        newWays.push([...w, c]);
                    }
                }
                ways = newWays;
            }
            for (let w of ways) {
                let isSF = w.every(c => c.suit === w[0].suit);
                if (isSF) {
                    addHand("同花顺", 15, w);
                } else {
                    addHand("顺子", 6, w);
                }
            }
        }
    }
    
    return candidates;
}

function calculateBestPokerHand(cards, chainValueSum = 0, cardCountMultiplier = 1, collisionMultiplier = 1) {
    if (!cards || cards.length === 0) {
        return {
            hands: [],
            formulaBaseScore: 0
        };
    }
    
    let candidates = generateCandidateHands(cards);
    candidates.sort((a, b) => b.bonus - a.bonus);
    
    let bestCombo = [];
    let bestBonusSum = 0;

    function dfs(index, currentMask, currentBonusSum, currentHands) {
        if (currentBonusSum > bestBonusSum) {
            bestBonusSum = currentBonusSum;
            bestCombo = [...currentHands];
        }

        let maxPossibleBonus = 0;
        let tempMask = currentMask;
        for (let i = index; i < candidates.length; i++) {
            if ((tempMask & candidates[i].mask) === 0n) {
                maxPossibleBonus += candidates[i].bonus;
                tempMask |= candidates[i].mask;
            }
        }

        if (currentBonusSum + maxPossibleBonus <= bestBonusSum) return;
        
        for (let i = index; i < candidates.length; i++) {
            let cand = candidates[i];
            if ((currentMask & cand.mask) === 0n) {
                currentHands.push(cand);
                dfs(
                    i + 1,
                    currentMask | cand.mask,
                    currentBonusSum + cand.bonus,
                    currentHands
                );
                currentHands.pop();
            }
        }
    }
    
    dfs(0, 0n, 0, []);
    
    let finalBaseScore = chainValueSum + bestBonusSum;
    let formulaScore = Math.ceil(finalBaseScore * cardCountMultiplier * collisionMultiplier);
    
    return {
        hands: bestCombo,
        formulaBaseScore: formulaScore
    };
}


function buildPlayAreaGroups(pokerHands) {
    if (!pokerHands || pokerHands.length === 0) return [];
    return pokerHands.map(hand => ({
        name: hand.name,
        cards: hand.subset.map(card => ({
            id: card.id,
            suit: card.suit,
            rank: card.rank,
            value: card.value,
            color: card.color
        }))
    }));
}

async function advanceRoundAfterSettlement(isTurnAdvance = true) {
    // Level clear: reaching target score ends current round and enters next level
    if (score >= levelTargetScore) {
        await sleep(450);
        showLevelClearModal();
        return;
    }

    // Round start pre-process: return the white active-card-insert back to deck and draw one from left
    processPendingWhiteReturn(isTurnAdvance);

    if (!activeCard && handQueue.length > 0) {
        activeCard = handQueue.pop();
    }

    if (shouldEndGame()) {
        updateUI();
        showGameOver();
        setTimeout(hideComboBadge, 1500);
        return;
    }

    updateUI();

    setTimeout(hideComboBadge, 1500);
}


async function confirmRoundSettlement() {
    if (!isAwaitingRoundConfirm) return;

    isProcessing = true;

    for (let i = 0; i < playAreaCards.length; i++) {
        const cardId = playAreaCards[i].id;
        const el = document.querySelector(`#play-area-container [data-card-id="${cardId}"]`);
        if (el) {
            el.classList.add('anim-joker-highlight');
        }
        await sleep(120);
    }
    await sleep(380);

    playAreaCards = [];
    playAreaGroups = [];
    isAwaitingRoundConfirm = false;
    setConfirmButtonState(false);
    updateUI();

    await advanceRoundAfterSettlement();

    isProcessing = false;
}

// Process matches and potential chain collisions iteratively
async function checkAndResolveMatches(initialCheckIndex) {
    let stepCount = 0;
    
    let totalCardsToDraw = 0;
    let indicesToCheck = [];
    if (initialCheckIndex >= 0 && initialCheckIndex < handQueue.length) {
        indicesToCheck.push(initialCheckIndex);
    }
    
    while (indicesToCheck.length > 0 || totalCardsToDraw > 0) {
        if (indicesToCheck.length > 0) {
            let checkIndex = indicesToCheck.shift();
            if (checkIndex < 0 || checkIndex >= handQueue.length) continue;
            
            let match = getMatchSegment(checkIndex);
            if (match) {
                stepCount++;
                const start = match.start;
                const matchLength = match.length;

                // Extract matched cards, replace with placeholders
                const matchedCards = handQueue.splice(start, matchLength, ...Array(matchLength).fill(null).map(() => ({isPlaceholder: true})));
                playAreaCards.push(...matchedCards);
                
                // Fly cards to play area
                updateUI();
                await sleep(400);
                
                // Clear placeholders
                handQueue.splice(start, matchLength);
                updateUI();
                await sleep(300);
                
                totalCardsToDraw += matchLength;
                
                // Check for gap closure
                if (start > 0 && start < handQueue.length) {
                    const leftCard = handQueue[start - 1];
                    const rightCard = handQueue[start];
                    if (leftCard && rightCard && !isWhiteCard(leftCard) && !isWhiteCard(rightCard) && leftCard.suit === rightCard.suit) {
                        indicesToCheck.push(start - 1);
                    }
                }
                
                continue;
            }
        }
        
        if (indicesToCheck.length === 0 && totalCardsToDraw > 0) {
            isDrawingPhase = true;
            let drawnCount = drawNormalCardToHandQueue(totalCardsToDraw, false);
            totalCardsToDraw = 0;
            
            updateUI();
            isDrawingPhase = false;
            await sleep(500);
            
            if (drawnCount > 0) {
                if (isDebugMode) {
                    await new Promise(resolve => {
                        debugContinueResolver = resolve;
                        if (debugContinueBtn) {
                            debugContinueBtn.classList.remove('hidden');
                        }
                    });
                }
                
                // Check for collision at the boundary between newly drawn cards and existing cards
                if (drawnCount > 0 && drawnCount < handQueue.length) {
                    const leftCard = handQueue[drawnCount - 1];
                    const rightCard = handQueue[drawnCount];
                    if (leftCard && rightCard && !isWhiteCard(leftCard) && !isWhiteCard(rightCard) && leftCard.suit === rightCard.suit) {
                        indicesToCheck.push(drawnCount - 1);
                    }
                }
            }
        }
    }
    
    if (playAreaCards.length > 0) {
        let collisionCount = Math.max(0, stepCount - 1);
        let collisionMultiplier = Math.pow(2, collisionCount);
        
        let chainCardsCount = playAreaCards.length;
        let chainValueSum = 0;
        for (let c of playAreaCards) {
            chainValueSum += c.value;
        }
        
        let cardCountMultiplier = 1 + (chainCardsCount - 3) * 0.5;
        let pokerResult = calculateBestPokerHand(playAreaCards, chainValueSum, cardCountMultiplier, collisionMultiplier);
        let bestHands = pokerResult.hands;
        
        let roundScore = Math.max(0, pokerResult.formulaBaseScore);
        score += roundScore;

        playAreaGroups = buildPlayAreaGroups(bestHands);
        isAwaitingRoundConfirm = true;
        setConfirmButtonState(true);
        updateUI();
        
        if (score > highScore) {
            highScore = score;
            isNewRecord = true;
            localStorage.setItem('fifocard_highscore', highScore);
            updateUI();
        }
        
        showComboBadge(chainCardsCount, cardCountMultiplier, collisionMultiplier, bestHands, roundScore);
    }
}


function showComboBadge(cards, cardCountMult, collisionMult, pokerHands, addedScore) {
    if (!comboBadge) return;
    
    comboBadge.classList.remove('opacity-100', 'translate-y-0');
    comboBadge.classList.add('opacity-0', 'translate-y-2');
    
    let handsHtml = pokerHands.map(h => `<span class="bg-blue-100 text-blue-800 text-xs px-2 py-0.5 rounded ml-1">${h.name}</span>`).join('');
    
    let html = `
        <div class="flex flex-col items-center">
            <div class="text-lg font-bold">
                ${cards} Cards 
                <span class="text-yellow-500">x${cardCountMult}</span>
                ${collisionMult > 1 ? `<span class="text-red-500 ml-2">💥x${collisionMult}</span>` : ''}
            </div>
            ${handsHtml ? `<div class="mt-1">${handsHtml}</div>` : ''}
            <div class="text-2xl text-green-500 font-extrabold mt-1">+${addedScore}</div>
        </div>
    `;
    
    setTimeout(() => {
        comboBadge.innerHTML = html;
        comboBadge.classList.remove('opacity-0', 'translate-y-2');
        comboBadge.classList.add('opacity-100', 'translate-y-0');
        
        scoreDisplay.classList.add('text-green-500', 'scale-110');
        setTimeout(() => {
            scoreDisplay.classList.remove('text-green-500', 'scale-110');
        }, 300);
    }, 50);
}

function hideComboBadge() {
    if (comboBadge) {
        comboBadge.classList.remove('opacity-100', 'translate-y-0');
        comboBadge.classList.add('opacity-0', 'translate-y-2');
    }
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

if (nextLevelBtn) {
    nextLevelBtn.addEventListener('click', () => {
        hideLevelClearModal();
        setTimeout(showShopModal, 300);
    });
}

if (closeShopBtn) {
    closeShopBtn.addEventListener('click', () => {
        hideShopModal();
        startNextLevel();
    });
}

function showShopModal() {
    if (!shopModal) return;

    // Draw up to 2 items from itemDeck
    shopCards = [];
    for (let i = 0; i < 2; i++) {
        if (itemDeck.length > 0) {
            shopCards.push(itemDeck.pop());
        }
    }

    renderShopCards();

    shopModal.classList.remove('hidden');
    setTimeout(() => {
        shopModal.classList.remove('opacity-0');
        const content = document.getElementById('shop-modal-content');
        if (content) {
            content.classList.remove('scale-95');
            content.classList.add('scale-100');
        }
    }, 10);
}

function renderShopCards() {
    if (!shopCardsContainer) return;
    shopCardsContainer.innerHTML = '';

    if (shopCards.length === 0) {
        shopCardsContainer.innerHTML = '<span class="text-gray-500">牌堆中已没有道具</span>';
        return;
    }

    shopCards.forEach((card, index) => {
        const itemWrapper = document.createElement('div');
        itemWrapper.className = 'flex flex-col items-center gap-3 bg-gray-50 p-4 rounded-xl border border-gray-200';

        const cardEl = createCardElement(card);
        // remove enter anim
        cardEl.classList.remove('anim-enter');
        itemWrapper.appendChild(cardEl);

        const price = ITEM_PRICES[card.type] || 3;
        const buyBtn = document.createElement('button');
        
        // Check if there's space and enough gold
        const hasSpace = !itemSlots[0] || !itemSlots[1];
        const canAfford = gold >= price;
        
        buyBtn.className = `px-6 py-2 rounded-lg text-sm font-bold shadow-sm transition-colors ${hasSpace && canAfford ? 'bg-yellow-400 hover:bg-yellow-500 text-yellow-900' : 'bg-gray-300 text-gray-500 cursor-not-allowed'}`;
        buyBtn.innerText = `购买 (${price} 金币)`;
        buyBtn.disabled = !hasSpace || !canAfford;

        buyBtn.addEventListener('click', () => {
            if (gold >= price && (!itemSlots[0] || !itemSlots[1])) {
                gold -= price;
                // Add to slot
                if (!itemSlots[0]) {
                    itemSlots[0] = card;
                } else {
                    itemSlots[1] = card;
                }
                shopCards.splice(index, 1);
                updateUI();
                renderShopCards();
            }
        });

        itemWrapper.appendChild(buyBtn);
        shopCardsContainer.appendChild(itemWrapper);
    });
}

function hideShopModal() {
    if (!shopModal) return;
    
    // Return unbought cards to itemDeck
    if (shopCards.length > 0) {
        itemDeck.push(...shopCards);
        shopCards = [];
        // shuffle itemDeck
        for (let i = itemDeck.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [itemDeck[i], itemDeck[j]] = [itemDeck[j], itemDeck[i]];
        }
    }

    shopModal.classList.add('opacity-0');
    const content = document.getElementById('shop-modal-content');
    if (content) {
        content.classList.remove('scale-100');
        content.classList.add('scale-95');
    }
    setTimeout(() => {
        shopModal.classList.add('hidden');
    }, 300);
}

function showLevelClearModal() {
    if (!levelClearModal) return;
    
    // Calculate interest and rewards
    const currentGold = gold;
    const interest = Math.floor(currentGold / 5);
    const reward = 3;
    
    // Update total gold
    gold = currentGold + interest + reward;
    
    // Update modal DOM
    if (lcCurrentGold) lcCurrentGold.innerText = currentGold;
    if (lcInterest) lcInterest.innerText = `+${interest}`;
    if (lcReward) lcReward.innerText = `+${reward}`;
    if (lcTotalGold) lcTotalGold.innerText = gold;
    
    levelClearModal.classList.remove('hidden');
    // small delay to allow display:block to apply before changing opacity
    setTimeout(() => {
        levelClearModal.classList.remove('opacity-0');
        const content = document.getElementById('level-clear-modal-content');
        if(content) {
            content.classList.remove('scale-95');
            content.classList.add('scale-100');
        }
    }, 10);
    
    updateUI();
}

function hideLevelClearModal() {
    if (!levelClearModal) return;
    levelClearModal.classList.add('opacity-0');
    const content = document.getElementById('level-clear-modal-content');
    if(content) {
        content.classList.remove('scale-100');
        content.classList.add('scale-95');
    }
    setTimeout(() => {
        levelClearModal.classList.add('hidden');
    }, 300);
}

function showGameOver() {
    finalScoreDisplay.innerText = score;
    
    const newRecordBadge = document.getElementById('new-record-badge');
    if (newRecordBadge) {
        if (isNewRecord && score > 0) {
            newRecordBadge.classList.remove('hidden');
        } else {
            newRecordBadge.classList.add('hidden');
        }
    }
    
    gameOverModal.classList.remove('hidden');
    // slight delay for animation
    setTimeout(() => {
        gameOverModal.classList.remove('opacity-0');
        gameOverModal.querySelector('#modal-content').classList.remove('scale-95');
    }, 10);
}

function hideGameOver() {
    gameOverModal.classList.add('opacity-0');
    gameOverModal.querySelector('#modal-content').classList.add('scale-95');
    setTimeout(() => {
        gameOverModal.classList.add('hidden');
    }, 300);
}

// Start Game
initGame();
