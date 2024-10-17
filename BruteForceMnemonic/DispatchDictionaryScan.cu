#include <stdafx.h>

#include <iostream>
#include <thread>

#include "cuda_runtime.h"

#include "DispatchDictionaryScan.cuh"
#include "DictionaryScanner.cuh"

#include "consts.h"
#include "AdaptiveBase.h"


#include "../Tools/tools.h"
#include "../Tools/utils.h"
#include "Helper.h"
#include "EntropyTools.cuh"

#include <windows.h> //some beeping fancey
#include <mmsystem.h>

#define _USE_MATH_DEFINES
#include <cmath>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif


// 18 kB
const uint8_t arrBipWords[2048][9] = { "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd","abuse", "access", "accident", "account", "accuse", "achieve", "acid", "acoustic", "acquire","across", "act", "action", "actor", "actress", "actual", "adapt", "add", "addict", "address","adjust", "admit", "adult", "advance", "advice", "aerobic", "affair", "afford", "afraid","again", "age", "agent", "agree", "ahead", "aim", "air", "airport", "aisle", "alarm", "album","alcohol", "alert", "alien", "all", "alley", "allow", "almost", "alone", "alpha", "already","also", "alter", "always", "amateur", "amazing", "among", "amount", "amused", "analyst","anchor", "ancient", "anger", "angle", "angry", "animal", "ankle", "announce", "annual","another", "answer", "antenna", "antique", "anxiety", "any", "apart", "apology", "appear","apple", "approve", "april", "arch", "arctic", "area", "arena", "argue", "arm", "armed","armor", "army", "around", "arrange", "arrest", "arrive", "arrow", "art", "artefact", "artist","artwork", "ask", "aspect", "assault", "asset", "assist", "assume", "asthma", "athlete","atom", "attack", "attend", "attitude", "attract", "auction", "audit", "august", "aunt","author", "auto", "autumn", "average", "avocado", "avoid", "awake", "aware", "away", "awesome","awful", "awkward", "axis", "baby", "bachelor", "bacon", "badge", "bag", "balance", "balcony","ball", "bamboo", "banana", "banner", "bar", "barely", "bargain", "barrel", "base", "basic","basket", "battle", "beach", "bean", "beauty", "because", "become", "beef", "before", "begin","behave", "behind", "believe", "below", "belt", "bench", "benefit", "best", "betray", "better","between", "beyond", "bicycle", "bid", "bike", "bind", "biology", "bird", "birth", "bitter","black", "blade", "blame", "blanket", "blast", "bleak", "bless", "blind", "blood", "blossom","blouse", "blue", "blur", "blush", "board", "boat", "body", "boil", "bomb", "bone", "bonus","book", "boost", "border", "boring", "borrow", "boss", "bottom", "bounce", "box", "boy","bracket", "brain", "brand", "brass", "brave", "bread", "breeze", "brick", "bridge", "brief","bright", "bring", "brisk", "broccoli", "broken", "bronze", "broom", "brother", "brown","brush", "bubble", "buddy", "budget", "buffalo", "build", "bulb", "bulk", "bullet", "bundle","bunker", "burden", "burger", "burst", "bus", "business", "busy", "butter", "buyer", "buzz","cabbage", "cabin", "cable", "cactus", "cage", "cake", "call", "calm", "camera", "camp", "can","canal", "cancel", "candy", "cannon", "canoe", "canvas", "canyon", "capable", "capital","captain", "car", "carbon", "card", "cargo", "carpet", "carry", "cart", "case", "cash","casino", "castle", "casual", "cat", "catalog", "catch", "category", "cattle", "caught","cause", "caution", "cave", "ceiling", "celery", "cement", "census", "century", "cereal","certain", "chair", "chalk", "champion", "change", "chaos", "chapter", "charge", "chase","chat", "cheap", "check", "cheese", "chef", "cherry", "chest", "chicken", "chief", "child","chimney", "choice", "choose", "chronic", "chuckle", "chunk", "churn", "cigar", "cinnamon","circle", "citizen", "city", "civil", "claim", "clap", "clarify", "claw", "clay", "clean","clerk", "clever", "click", "client", "cliff", "climb", "clinic", "clip", "clock", "clog","close", "cloth", "cloud", "clown", "club", "clump", "cluster", "clutch", "coach", "coast","coconut", "code", "coffee", "coil", "coin", "collect", "color", "column", "combine", "come","comfort", "comic", "common", "company", "concert", "conduct", "confirm", "congress","connect", "consider", "control", "convince", "cook", "cool", "copper", "copy", "coral","core", "corn", "correct", "cost", "cotton", "couch", "country", "couple", "course", "cousin","cover", "coyote", "crack", "cradle", "craft", "cram", "crane", "crash", "crater", "crawl","crazy", "cream", "credit", "creek", "crew", "cricket", "crime", "crisp", "critic", "crop","cross", "crouch", "crowd", "crucial", "cruel", "cruise", "crumble", "crunch", "crush", "cry","crystal", "cube", "culture", "cup", "cupboard", "curious", "current", "curtain", "curve","cushion", "custom", "cute", "cycle", "dad", "damage", "damp", "dance", "danger", "daring","dash", "daughter", "dawn", "day", "deal", "debate", "debris", "decade", "december", "decide","decline", "decorate", "decrease", "deer", "defense", "define", "defy", "degree", "delay","deliver", "demand", "demise", "denial", "dentist", "deny", "depart", "depend", "deposit","depth", "deputy", "derive", "describe", "desert", "design", "desk", "despair", "destroy","detail", "detect", "develop", "device", "devote", "diagram", "dial", "diamond", "diary","dice", "diesel", "diet", "differ", "digital", "dignity", "dilemma", "dinner", "dinosaur","direct", "dirt", "disagree", "discover", "disease", "dish", "dismiss", "disorder", "display","distance", "divert", "divide", "divorce", "dizzy", "doctor", "document", "dog", "doll","dolphin", "domain", "donate", "donkey", "donor", "door", "dose", "double", "dove", "draft","dragon", "drama", "drastic", "draw", "dream", "dress", "drift", "drill", "drink", "drip","drive", "drop", "drum", "dry", "duck", "dumb", "dune", "during", "dust", "dutch", "duty","dwarf", "dynamic", "eager", "eagle", "early", "earn", "earth", "easily", "east", "easy","echo", "ecology", "economy", "edge", "edit", "educate", "effort", "egg", "eight", "either","elbow", "elder", "electric", "elegant", "element", "elephant", "elevator", "elite", "else","embark", "embody", "embrace", "emerge", "emotion", "employ", "empower", "empty", "enable","enact", "end", "endless", "endorse", "enemy", "energy", "enforce", "engage", "engine","enhance", "enjoy", "enlist", "enough", "enrich", "enroll", "ensure", "enter", "entire","entry", "envelope", "episode", "equal", "equip", "era", "erase", "erode", "erosion", "error","erupt", "escape", "essay", "essence", "estate", "eternal", "ethics", "evidence", "evil","evoke", "evolve", "exact", "example", "excess", "exchange", "excite", "exclude", "excuse","execute", "exercise", "exhaust", "exhibit", "exile", "exist", "exit", "exotic", "expand","expect", "expire", "explain", "expose", "express", "extend", "extra", "eye", "eyebrow","fabric", "face", "faculty", "fade", "faint", "faith", "fall", "false", "fame", "family","famous", "fan", "fancy", "fantasy", "farm", "fashion", "fat", "fatal", "father", "fatigue","fault", "favorite", "feature", "february", "federal", "fee", "feed", "feel", "female","fence", "festival", "fetch", "fever", "few", "fiber", "fiction", "field", "figure", "file","film", "filter", "final", "find", "fine", "finger", "finish", "fire", "firm", "first","fiscal", "fish", "fit", "fitness", "fix", "flag", "flame", "flash", "flat", "flavor", "flee","flight", "flip", "float", "flock", "floor", "flower", "fluid", "flush", "fly", "foam","focus", "fog", "foil", "fold", "follow", "food", "foot", "force", "forest", "forget", "fork","fortune", "forum", "forward", "fossil", "foster", "found", "fox", "fragile", "frame","frequent", "fresh", "friend", "fringe", "frog", "front", "frost", "frown", "frozen", "fruit","fuel", "fun", "funny", "furnace", "fury", "future", "gadget", "gain", "galaxy", "gallery","game", "gap", "garage", "garbage", "garden", "garlic", "garment", "gas", "gasp", "gate","gather", "gauge", "gaze", "general", "genius", "genre", "gentle", "genuine", "gesture","ghost", "giant", "gift", "giggle", "ginger", "giraffe", "girl", "give", "glad", "glance","glare", "glass", "glide", "glimpse", "globe", "gloom", "glory", "glove", "glow", "glue","goat", "goddess", "gold", "good", "goose", "gorilla", "gospel", "gossip", "govern", "gown","grab", "grace", "grain", "grant", "grape", "grass", "gravity", "great", "green", "grid","grief", "grit", "grocery", "group", "grow", "grunt", "guard", "guess", "guide", "guilt","guitar", "gun", "gym", "habit", "hair", "half", "hammer", "hamster", "hand", "happy","harbor", "hard", "harsh", "harvest", "hat", "have", "hawk", "hazard", "head", "health","heart", "heavy", "hedgehog", "height", "hello", "helmet", "help", "hen", "hero", "hidden","high", "hill", "hint", "hip", "hire", "history", "hobby", "hockey", "hold", "hole", "holiday","hollow", "home", "honey", "hood", "hope", "horn", "horror", "horse", "hospital", "host","hotel", "hour", "hover", "hub", "huge", "human", "humble", "humor", "hundred", "hungry","hunt", "hurdle", "hurry", "hurt", "husband", "hybrid", "ice", "icon", "idea", "identify","idle", "ignore", "ill", "illegal", "illness", "image", "imitate", "immense", "immune","impact", "impose", "improve", "impulse", "inch", "include", "income", "increase", "index","indicate", "indoor", "industry", "infant", "inflict", "inform", "inhale", "inherit","initial", "inject", "injury", "inmate", "inner", "innocent", "input", "inquiry", "insane","insect", "inside", "inspire", "install", "intact", "interest", "into", "invest", "invite","involve", "iron", "island", "isolate", "issue", "item", "ivory", "jacket", "jaguar", "jar","jazz", "jealous", "jeans", "jelly", "jewel", "job", "join", "joke", "journey", "joy", "judge","juice", "jump", "jungle", "junior", "junk", "just", "kangaroo", "keen", "keep", "ketchup","key", "kick", "kid", "kidney", "kind", "kingdom", "kiss", "kit", "kitchen", "kite", "kitten","kiwi", "knee", "knife", "knock", "know", "lab", "label", "labor", "ladder", "lady", "lake","lamp", "language", "laptop", "large", "later", "latin", "laugh", "laundry", "lava", "law","lawn", "lawsuit", "layer", "lazy", "leader", "leaf", "learn", "leave", "lecture", "left","leg", "legal", "legend", "leisure", "lemon", "lend", "length", "lens", "leopard", "lesson","letter", "level", "liar", "liberty", "library", "license", "life", "lift", "light", "like","limb", "limit", "link", "lion", "liquid", "list", "little", "live", "lizard", "load", "loan","lobster", "local", "lock", "logic", "lonely", "long", "loop", "lottery", "loud", "lounge","love", "loyal", "lucky", "luggage", "lumber", "lunar", "lunch", "luxury", "lyrics", "machine","mad", "magic", "magnet", "maid", "mail", "main", "major", "make", "mammal", "man", "manage","mandate", "mango", "mansion", "manual", "maple", "marble", "march", "margin", "marine","market", "marriage", "mask", "mass", "master", "match", "material", "math", "matrix","matter", "maximum", "maze", "meadow", "mean", "measure", "meat", "mechanic", "medal", "media","melody", "melt", "member", "memory", "mention", "menu", "mercy", "merge", "merit", "merry","mesh", "message", "metal", "method", "middle", "midnight", "milk", "million", "mimic", "mind","minimum", "minor", "minute", "miracle", "mirror", "misery", "miss", "mistake", "mix", "mixed","mixture", "mobile", "model", "modify", "mom", "moment", "monitor", "monkey", "monster","month", "moon", "moral", "more", "morning", "mosquito", "mother", "motion", "motor","mountain", "mouse", "move", "movie", "much", "muffin", "mule", "multiply", "muscle", "museum","mushroom", "music", "must", "mutual", "myself", "mystery", "myth", "naive", "name", "napkin","narrow", "nasty", "nation", "nature", "near", "neck", "need", "negative", "neglect","neither", "nephew", "nerve", "nest", "net", "network", "neutral", "never", "news", "next","nice", "night", "noble", "noise", "nominee", "noodle", "normal", "north", "nose", "notable","note", "nothing", "notice", "novel", "now", "nuclear", "number", "nurse", "nut", "oak","obey", "object", "oblige", "obscure", "observe", "obtain", "obvious", "occur", "ocean","october", "odor", "off", "offer", "office", "often", "oil", "okay", "old", "olive", "olympic","omit", "once", "one", "onion", "online", "only", "open", "opera", "opinion", "oppose","option", "orange", "orbit", "orchard", "order", "ordinary", "organ", "orient", "original","orphan", "ostrich", "other", "outdoor", "outer", "output", "outside", "oval", "oven", "over","own", "owner", "oxygen", "oyster", "ozone", "pact", "paddle", "page", "pair", "palace","palm", "panda", "panel", "panic", "panther", "paper", "parade", "parent", "park", "parrot","party", "pass", "patch", "path", "patient", "patrol", "pattern", "pause", "pave", "payment","peace", "peanut", "pear", "peasant", "pelican", "pen", "penalty", "pencil", "people","pepper", "perfect", "permit", "person", "pet", "phone", "photo", "phrase", "physical","piano", "picnic", "picture", "piece", "pig", "pigeon", "pill", "pilot", "pink", "pioneer","pipe", "pistol", "pitch", "pizza", "place", "planet", "plastic", "plate", "play", "please","pledge", "pluck", "plug", "plunge", "poem", "poet", "point", "polar", "pole", "police","pond", "pony", "pool", "popular", "portion", "position", "possible", "post", "potato","pottery", "poverty", "powder", "power", "practice", "praise", "predict", "prefer", "prepare","present", "pretty", "prevent", "price", "pride", "primary", "print", "priority", "prison","private", "prize", "problem", "process", "produce", "profit", "program", "project", "promote","proof", "property", "prosper", "protect", "proud", "provide", "public", "pudding", "pull","pulp", "pulse", "pumpkin", "punch", "pupil", "puppy", "purchase", "purity", "purpose","purse", "push", "put", "puzzle", "pyramid", "quality", "quantum", "quarter", "question","quick", "quit", "quiz", "quote", "rabbit", "raccoon", "race", "rack", "radar", "radio","rail", "rain", "raise", "rally", "ramp", "ranch", "random", "range", "rapid", "rare", "rate","rather", "raven", "raw", "razor", "ready", "real", "reason", "rebel", "rebuild", "recall","receive", "recipe", "record", "recycle", "reduce", "reflect", "reform", "refuse", "region","regret", "regular", "reject", "relax", "release", "relief", "rely", "remain", "remember","remind", "remove", "render", "renew", "rent", "reopen", "repair", "repeat", "replace","report", "require", "rescue", "resemble", "resist", "resource", "response", "result","retire", "retreat", "return", "reunion", "reveal", "review", "reward", "rhythm", "rib","ribbon", "rice", "rich", "ride", "ridge", "rifle", "right", "rigid", "ring", "riot", "ripple","risk", "ritual", "rival", "river", "road", "roast", "robot", "robust", "rocket", "romance","roof", "rookie", "room", "rose", "rotate", "rough", "round", "route", "royal", "rubber","rude", "rug", "rule", "run", "runway", "rural", "sad", "saddle", "sadness", "safe", "sail","salad", "salmon", "salon", "salt", "salute", "same", "sample", "sand", "satisfy", "satoshi","sauce", "sausage", "save", "say", "scale", "scan", "scare", "scatter", "scene", "scheme","school", "science", "scissors", "scorpion", "scout", "scrap", "screen", "script", "scrub","sea", "search", "season", "seat", "second", "secret", "section", "security", "seed", "seek","segment", "select", "sell", "seminar", "senior", "sense", "sentence", "series", "service","session", "settle", "setup", "seven", "shadow", "shaft", "shallow", "share", "shed", "shell","sheriff", "shield", "shift", "shine", "ship", "shiver", "shock", "shoe", "shoot", "shop","short", "shoulder", "shove", "shrimp", "shrug", "shuffle", "shy", "sibling", "sick", "side","siege", "sight", "sign", "silent", "silk", "silly", "silver", "similar", "simple", "since","sing", "siren", "sister", "situate", "six", "size", "skate", "sketch", "ski", "skill", "skin","skirt", "skull", "slab", "slam", "sleep", "slender", "slice", "slide", "slight", "slim","slogan", "slot", "slow", "slush", "small", "smart", "smile", "smoke", "smooth", "snack","snake", "snap", "sniff", "snow", "soap", "soccer", "social", "sock", "soda", "soft", "solar","soldier", "solid", "solution", "solve", "someone", "song", "soon", "sorry", "sort", "soul","sound", "soup", "source", "south", "space", "spare", "spatial", "spawn", "speak", "special","speed", "spell", "spend", "sphere", "spice", "spider", "spike", "spin", "spirit", "split","spoil", "sponsor", "spoon", "sport", "spot", "spray", "spread", "spring", "spy", "square","squeeze", "squirrel", "stable", "stadium", "staff", "stage", "stairs", "stamp", "stand","start", "state", "stay", "steak", "steel", "stem", "step", "stereo", "stick", "still","sting", "stock", "stomach", "stone", "stool", "story", "stove", "strategy", "street","strike", "strong", "struggle", "student", "stuff", "stumble", "style", "subject", "submit","subway", "success", "such", "sudden", "suffer", "sugar", "suggest", "suit", "summer", "sun","sunny", "sunset", "super", "supply", "supreme", "sure", "surface", "surge", "surprise","surround", "survey", "suspect", "sustain", "swallow", "swamp", "swap", "swarm", "swear","sweet", "swift", "swim", "swing", "switch", "sword", "symbol", "symptom", "syrup", "system","table", "tackle", "tag", "tail", "talent", "talk", "tank", "tape", "target", "task", "taste","tattoo", "taxi", "teach", "team", "tell", "ten", "tenant", "tennis", "tent", "term", "test","text", "thank", "that", "theme", "then", "theory", "there", "they", "thing", "this","thought", "three", "thrive", "throw", "thumb", "thunder", "ticket", "tide", "tiger", "tilt","timber", "time", "tiny", "tip", "tired", "tissue", "title", "toast", "tobacco", "today","toddler", "toe", "together", "toilet", "token", "tomato", "tomorrow", "tone", "tongue","tonight", "tool", "tooth", "top", "topic", "topple", "torch", "tornado", "tortoise", "toss","total", "tourist", "toward", "tower", "town", "toy", "track", "trade", "traffic", "tragic","train", "transfer", "trap", "trash", "travel", "tray", "treat", "tree", "trend", "trial","tribe", "trick", "trigger", "trim", "trip", "trophy", "trouble", "truck", "true", "truly","trumpet", "trust", "truth", "try", "tube", "tuition", "tumble", "tuna", "tunnel", "turkey","turn", "turtle", "twelve", "twenty", "twice", "twin", "twist", "two", "type", "typical","ugly", "umbrella", "unable", "unaware", "uncle", "uncover", "under", "undo", "unfair","unfold", "unhappy", "uniform", "unique", "unit", "universe", "unknown", "unlock", "until","unusual", "unveil", "update", "upgrade", "uphold", "upon", "upper", "upset", "urban", "urge","usage", "use", "used", "useful", "useless", "usual", "utility", "vacant", "vacuum", "vague","valid", "valley", "valve", "van", "vanish", "vapor", "various", "vast", "vault", "vehicle","velvet", "vendor", "venture", "venue", "verb", "verify", "version", "very", "vessel","veteran", "viable", "vibrant", "vicious", "victory", "video", "view", "village", "vintage","violin", "virtual", "virus", "visa", "visit", "visual", "vital", "vivid", "vocal", "voice","void", "volcano", "volume", "vote", "voyage", "wage", "wagon", "wait", "walk", "wall","walnut", "want", "warfare", "warm", "warrior", "wash", "wasp", "waste", "water", "wave","way", "wealth", "weapon", "wear", "weasel", "weather", "web", "wedding", "weekend", "weird","welcome", "west", "wet", "whale", "what", "wheat", "wheel", "when", "where", "whip","whisper", "wide", "width", "wife", "wild", "will", "win", "window", "wine", "wing", "wink","winner", "winter", "wire", "wisdom", "wise", "wish", "witness", "wolf", "woman", "wonder","wood", "wool", "word", "work", "world", "worry", "worth", "wrap", "wreck", "wrestle", "wrist","write", "wrong", "yard", "year", "yellow", "you", "young", "youth", "zebra", "zero", "zone","zoo" };
const uint8_t arrBipWordsLengths[2048] = { 7,7,4,5,5,6,6,8,6,5,6,8,7,6,7,4,8,7,6,3,6,5,7,6,5,3,6,7,6,5,5,7,6,7,6,6,6,5,3,5,5,5,3,3,7,5,5,5,7,5,5,3,5,5,6,5,5,7,4,5,6,7,7,5,6,6,7,6,7,5,5,5,6,5,8,6,7,6,7,7,7,3,5,7,6,5,7,5,4,6,4,5,5,3,5,5,4,6,7,6,6,5,3,8,6,7,3,6,7,5,6,6,6,7,4,6,6,8,7,7,5,6,4,6,4,6,7,7,5,5,5,4,7,5,7,4,4,8,5,5,3,7,7,4,6,6,6,3,6,7,6,4,5,6,6,5,4,6,7,6,4,6,5,6,6,7,5,4,5,7,4,6,6,7,6,7,3,4,4,7,4,5,6,5,5,5,7,5,5,5,5,5,7,6,4,4,5,5,4,4,4,4,4,5,4,5,6,6,6,4,6,6,3,3,7,5,5,5,5,5,6,5,6,5,6,5,5,8,6,6,5,7,5,5,6,5,6,7,5,4,4,6,6,6,6,6,5,3,8,4,6,5,4,7,5,5,6,4,4,4,4,6,4,3,5,6,5,6,5,6,6,7,7,7,3,6,4,5,6,5,4,4,4,6,6,6,3,7,5,8,6,6,5,7,4,7,6,6,6,7,6,7,5,5,8,6,5,7,6,5,4,5,5,6,4,6,5,7,5,5,7,6,6,7,7,5,5,5,8,6,7,4,5,5,4,7,4,4,5,5,6,5,6,5,5,6,4,5,4,5,5,5,5,4,5,7,6,5,5,7,4,6,4,4,7,5,6,7,4,7,5,6,7,7,7,7,8,7,8,7,8,4,4,6,4,5,4,4,7,4,6,5,7,6,6,6,5,6,5,6,5,4,5,5,6,5,5,5,6,5,4,7,5,5,6,4,5,6,5,7,5,6,7,6,5,3,7,4,7,3,8,7,7,7,5,7,6,4,5,3,6,4,5,6,6,4,8,4,3,4,6,6,6,8,6,7,8,8,4,7,6,4,6,5,7,6,6,6,7,4,6,6,7,5,6,6,8,6,6,4,7,7,6,6,7,6,6,7,4,7,5,4,6,4,6,7,7,7,6,8,6,4,8,8,7,4,7,8,7,8,6,6,7,5,6,8,3,4,7,6,6,6,5,4,4,6,4,5,6,5,7,4,5,5,5,5,5,4,5,4,4,3,4,4,4,6,4,5,4,5,7,5,5,5,4,5,6,4,4,4,7,7,4,4,7,6,3,5,6,5,5,8,7,7,8,8,5,4,6,6,7,6,7,6,7,5,6,5,3,7,7,5,6,7,6,6,7,5,6,6,6,6,6,5,6,5,8,7,5,5,3,5,5,7,5,5,6,5,7,6,7,6,8,4,5,6,5,7,6,8,6,7,6,7,8,7,7,5,5,4,6,6,6,6,7,6,7,6,5,3,7,6,4,7,4,5,5,4,5,4,6,6,3,5,7,4,7,3,5,6,7,5,8,7,8,7,3,4,4,6,5,8,5,5,3,5,7,5,6,4,4,6,5,4,4,6,6,4,4,5,6,4,3,7,3,4,5,5,4,6,4,6,4,5,5,5,6,5,5,3,4,5,3,4,4,6,4,4,5,6,6,4,7,5,7,6,6,5,3,7,5,8,5,6,6,4,5,5,5,6,5,4,3,5,7,4,6,6,4,6,7,4,3,6,7,6,6,7,3,4,4,6,5,4,7,6,5,6,7,7,5,5,4,6,6,7,4,4,4,6,5,5,5,7,5,5,5,5,4,4,4,7,4,4,5,7,6,6,6,4,4,5,5,5,5,5,7,5,5,4,5,4,7,5,4,5,5,5,5,5,6,3,3,5,4,4,6,7,4,5,6,4,5,7,3,4,4,6,4,6,5,5,8,6,5,6,4,3,4,6,4,4,4,3,4,7,5,6,4,4,7,6,4,5,4,4,4,6,5,8,4,5,4,5,3,4,5,6,5,7,6,4,6,5,4,7,6,3,4,4,8,4,6,3,7,7,5,7,7,6,6,6,7,7,4,7,6,8,5,8,6,8,6,7,6,6,7,7,6,6,6,5,8,5,7,6,6,6,7,7,6,8,4,6,6,7,4,6,7,5,4,5,6,6,3,4,7,5,5,5,3,4,4,7,3,5,5,4,6,6,4,4,8,4,4,7,3,4,3,6,4,7,4,3,7,4,6,4,4,5,5,4,3,5,5,6,4,4,4,8,6,5,5,5,5,7,4,3,4,7,5,4,6,4,5,5,7,4,3,5,6,7,5,4,6,4,7,6,6,5,4,7,7,7,4,4,5,4,4,5,4,4,6,4,6,4,6,4,4,7,5,4,5,6,4,4,7,4,6,4,5,5,7,6,5,5,6,6,7,3,5,6,4,4,4,5,4,6,3,6,7,5,7,6,5,6,5,6,6,6,8,4,4,6,5,8,4,6,6,7,4,6,4,7,4,8,5,5,6,4,6,6,7,4,5,5,5,5,4,7,5,6,6,8,4,7,5,4,7,5,6,7,6,6,4,7,3,5,7,6,5,6,3,6,7,6,7,5,4,5,4,7,8,6,6,5,8,5,4,5,4,6,4,8,6,6,8,5,4,6,6,7,4,5,4,6,6,5,6,6,4,4,4,8,7,7,6,5,4,3,7,7,5,4,4,4,5,5,5,7,6,6,5,4,7,4,7,6,5,3,7,6,5,3,3,4,6,6,7,7,6,7,5,5,7,4,3,5,6,5,3,4,3,5,7,4,4,3,5,6,4,4,5,7,6,6,6,5,7,5,8,5,6,8,6,7,5,7,5,6,7,4,4,4,3,5,6,6,5,4,6,4,4,6,4,5,5,5,7,5,6,6,4,6,5,4,5,4,7,6,7,5,4,7,5,6,4,7,7,3,7,6,6,6,7,6,6,3,5,5,6,8,5,6,7,5,3,6,4,5,4,7,4,6,5,5,5,6,7,5,4,6,6,5,4,6,4,4,5,5,4,6,4,4,4,7,7,8,8,4,6,7,7,6,5,8,6,7,6,7,7,6,7,5,5,7,5,8,6,7,5,7,7,7,6,7,7,7,5,8,7,7,5,7,6,7,4,4,5,7,5,5,5,8,6,7,5,4,3,6,7,7,7,7,8,5,4,4,5,6,7,4,4,5,5,4,4,5,5,4,5,6,5,5,4,4,6,5,3,5,5,4,6,5,7,6,7,6,6,7,6,7,6,6,6,6,7,6,5,7,6,4,6,8,6,6,6,5,4,6,6,6,7,6,7,6,8,6,8,8,6,6,7,6,7,6,6,6,6,3,6,4,4,4,5,5,5,5,4,4,6,4,6,5,5,4,5,5,6,6,7,4,6,4,4,6,5,5,5,5,6,4,3,4,3,6,5,3,6,7,4,4,5,6,5,4,6,4,6,4,7,7,5,7,4,3,5,4,5,7,5,6,6,7,8,8,5,5,6,6,5,3,6,6,4,6,6,7,8,4,4,7,6,4,7,6,5,8,6,7,7,6,5,5,6,5,7,5,4,5,7,6,5,5,4,6,5,4,5,4,5,8,5,6,5,7,3,7,4,4,5,5,4,6,4,5,6,7,6,5,4,5,6,7,3,4,5,6,3,5,4,5,5,4,4,5,7,5,5,6,4,6,4,4,5,5,5,5,5,6,5,5,4,5,4,4,6,6,4,4,4,5,7,5,8,5,7,4,4,5,4,4,5,4,6,5,5,5,7,5,5,7,5,5,5,6,5,6,5,4,6,5,5,7,5,5,4,5,6,6,3,6,7,8,6,7,5,5,6,5,5,5,5,4,5,5,4,4,6,5,5,5,5,7,5,5,5,5,8,6,6,6,8,7,5,7,5,7,6,6,7,4,6,6,5,7,4,6,3,5,6,5,6,7,4,7,5,8,8,6,7,7,7,5,4,5,5,5,5,4,5,6,5,6,7,5,6,5,6,3,4,6,4,4,4,6,4,5,6,4,5,4,4,3,6,6,4,4,4,4,5,4,5,4,6,5,4,5,4,7,5,6,5,5,7,6,4,5,4,6,4,4,3,5,6,5,5,7,5,7,3,8,6,5,6,8,4,6,7,4,5,3,5,6,5,7,8,4,5,7,6,5,4,3,5,5,7,6,5,8,4,5,6,4,5,4,5,5,5,5,7,4,4,6,7,5,4,5,7,5,5,3,4,7,6,4,6,6,4,6,6,6,5,4,5,3,4,7,4,8,6,7,5,7,5,4,6,6,7,7,6,4,8,7,6,5,7,6,6,7,6,4,5,5,5,4,5,3,4,6,7,5,7,6,6,5,5,6,5,3,6,5,7,4,5,7,6,6,7,5,4,6,7,4,6,7,6,7,7,7,5,4,7,7,6,7,5,4,5,6,5,5,5,5,4,7,6,4,6,4,5,4,4,4,6,4,7,4,7,4,4,5,5,4,3,6,6,4,6,7,3,7,7,5,7,4,3,5,4,5,5,4,5,4,7,4,5,4,4,4,3,6,4,4,4,6,6,4,6,4,4,7,4,5,6,4,4,4,4,5,5,5,4,5,7,5,5,5,4,4,6,3,5,5,5,4,4,3 };

void ShowAdaptiveStr(int16_t digs[MAX_ADAPTIVE_BASE_POSITIONS], char *str) {
	int16_t bipVal;
	uint16_t offset = 0;
	for (int i = 0; i < MAX_ADAPTIVE_BASE_POSITIONS; i++) {
		bipVal = host_AdaptiveBaseDigitSet[i][digs[i]];
		sprintf(str+offset, "%s ", arrBipWords [bipVal]);
		offset += arrBipWordsLengths[bipVal] + 1;
	}
}



//// A simple 1-second sine wave sound (440 Hz)
//const unsigned char soundDataSimple[] = {
//	0x52, 0x49, 0x46, 0x46, 0x24, 0x08, 0x00, 0x00, // RIFF header
//	0x57, 0x41, 0x56, 0x45, 0x66, 0x6d, 0x74, 0x20, // WAVE header
//	0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, // Format chunk
//	0x44, 0xac, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, // 44.1kHz, 16-bit
//	0x64, 0x61, 0x74, 0x61, 0x00, 0x08, 0x00, 0x00, // Data chunk header
//	// Actual audio data (440 Hz sine wave)
//	0x00, 0x00, 0x1d, 0x00, 0x38, 0x00, 0x4f, 0x00,
//	0x5e, 0x00, 0x64, 0x00, 0x68, 0x00, 0x6a, 0x00,
//	0x68, 0x00, 0x64, 0x00, 0x5e, 0x00, 0x4f, 0x00,
//	0x38, 0x00, 0x1d, 0x00, 0x00, 0x00, 0xe3, 0xff,
//	0xc8, 0xff, 0xa0, 0xff, 0x8f, 0xff, 0x7c, 0xff,
//	0x6f, 0xff, 0x68, 0xff, 0x68, 0xff, 0x70, 0xff,
//	0x7c, 0xff, 0x8f, 0xff, 0xa0, 0xff, 0xc8, 0xff,
//	0xe3, 0xff, 0x00, 0x00, 0x1d, 0x00, 0x38, 0x00,
//};

//void playWavFromMemory(const unsigned char* data, size_t size) {
//	HWAVEOUT hWaveOut;
//	WAVEFORMATEX wfx;
//
//	// Set up the WAVEFORMATEX structure
//	wfx.wFormatTag = WAVE_FORMAT_PCM;
//	wfx.nChannels = 1; // Mono
//	wfx.nSamplesPerSec = 44100; // Sample rate
//	wfx.wBitsPerSample = 16; // Bits per sample
//	wfx.nBlockAlign = (wfx.nChannels * wfx.wBitsPerSample) / 8;
//	wfx.nAvgBytesPerSec = wfx.nSamplesPerSec * wfx.nBlockAlign;
//
//	// Open the wave output device
//	waveOutOpen(&hWaveOut, WAVE_MAPPER, &wfx, 0, 0, CALLBACK_NULL);
//
//	// Prepare the wave header
//	WAVEHDR whdr;
//	whdr.lpData = (LPSTR)data; // Pointer to the data
//	whdr.dwBufferLength = (DWORD)size; // Size of the data
//	whdr.dwFlags = 0;
//
//	// Prepare and write the header
//	waveOutPrepareHeader(hWaveOut, &whdr, sizeof(WAVEHDR));
//	waveOutWrite(hWaveOut, &whdr, sizeof(WAVEHDR));
//
//	// Wait for the sound to finish playing
//	while (!(whdr.dwFlags & WHDR_DONE)) {
//		Sleep(100);
//	}
//
//	// Clean up
//	waveOutUnprepareHeader(hWaveOut, &whdr, sizeof(WAVEHDR));
//	waveOutClose(hWaveOut);
//}



const int SAMPLE_RATE = 44100;
const int DURATION = 1; // 1 second
const int FREQUENCY = 440; // Frequency of the sine wave (A4 note)

const int NUM_SAMPLES = SAMPLE_RATE * DURATION;
const int BYTE_RATE = SAMPLE_RATE * 2; // 16 bits = 2 bytes per sample

// Generating stereo sine wave data
unsigned char soundDataSine[NUM_SAMPLES * 4]; // 2 channels (stereo), 2 bytes per sample


void generateSineWave() {
	for (int i = 0; i < NUM_SAMPLES; i++) {
		// Calculate the sample value
		int16_t sample = static_cast<int16_t>(32767 * sin((2.0 * M_PI * FREQUENCY * i) / SAMPLE_RATE));

		// Fill left channel
		soundDataSine[i * 4] = (sample & 0xFF);          // Low byte
		soundDataSine[i * 4 + 1] = (sample >> 8) & 0xFF; // High byte

		// Fill right channel (same value for stereo effect)
		soundDataSine[i * 4 + 2] = (sample & 0xFF);      // Low byte
		soundDataSine[i * 4 + 3] = (sample >> 8) & 0xFF; // High byte
	}
}

void playSineWavFromMemory(const unsigned char* data, size_t size) {
	HWAVEOUT hWaveOut;
	WAVEFORMATEX wfx;

	// Set up the WAVEFORMATEX structure
	wfx.wFormatTag = WAVE_FORMAT_PCM;
	wfx.nChannels = 2; // Stereo
	wfx.nSamplesPerSec = SAMPLE_RATE; // Sample rate
	wfx.wBitsPerSample = 16; // Bits per sample
	wfx.nBlockAlign = (wfx.nChannels * wfx.wBitsPerSample) / 8;
	wfx.nAvgBytesPerSec = wfx.nSamplesPerSec * wfx.nBlockAlign;

	// Open the wave output device
	waveOutOpen(&hWaveOut, WAVE_MAPPER, &wfx, 0, 0, CALLBACK_NULL);

	// Prepare the wave header
	WAVEHDR whdr;
	whdr.lpData = (LPSTR)data; // Pointer to the data
	whdr.dwBufferLength = (DWORD)size; // Size of the data
	whdr.dwFlags = 0;

	// Prepare and write the header
	waveOutPrepareHeader(hWaveOut, &whdr, sizeof(WAVEHDR));
	waveOutWrite(hWaveOut, &whdr, sizeof(WAVEHDR));

	// Wait for the sound to finish playing
	while (!(whdr.dwFlags & WHDR_DONE)) {
		Sleep(100);
	}

	// Clean up
	waveOutUnprepareHeader(hWaveOut, &whdr, sizeof(WAVEHDR));
	waveOutClose(hWaveOut);
}


void playAlert() {
	//printf("Playing sound...\r\n");
	//Beep(2000, 1000);

	generateSineWave(); // Fill soundData with sine wave
	playSineWavFromMemory(soundDataSine, sizeof(soundDataSine));

	//playWavFromMemory(soundDataSimple, sizeof(soundDataSimple));
	//int frequencies[] = { 800, 1000, 1200, 1000 }; // Frequencies in Hz
	//int durations[] = { 300, 300, 300, 400 }; // Durations in milliseconds

	//for (int i = 0; i < sizeof(frequencies) / sizeof(frequencies[0]); ++i) {
	//	Beep(frequencies[i], durations[i]);
	//	Sleep(50);
	//}
}

bool  DispatchDictionaryScan(ConfigClass* Config, data_class* Data, stride_class* Stride) {

	if (InitalSync(Config) == false)
		return false;



	uint64_t nProblemPower =
		(uint64_t)host_AdaptiveBaseDigitCarryTrigger[0]
		* host_AdaptiveBaseDigitCarryTrigger[1]
		* host_AdaptiveBaseDigitCarryTrigger[2]
		* host_AdaptiveBaseDigitCarryTrigger[3]
		* host_AdaptiveBaseDigitCarryTrigger[4]
		* host_AdaptiveBaseDigitCarryTrigger[5];


	uint64_t nSolverThreads = Config->cuda_block * Config->cuda_grid;
	uint64_t nIterationPower = nSolverThreads * host_AdaptiveBaseDigitCarryTrigger[5];
	uint64_t nIterationsNeeded = nProblemPower / nIterationPower;

	if (nIterationsNeeded * nIterationPower < nProblemPower)
		nIterationsNeeded++;



	std::cout << "-- Starting Dictionary SCAN -- " << std::endl;

	std::cout << " Going to dispatch " << nProblemPower << " total COMBOs"
		<< " via " << nIterationsNeeded << " iterations "
		" (each able to process " << nIterationPower << " instances)." << std::endl;



	uint64_t nBatchMax = 1;

	int nBatch = 0;


	
	size_t copySize;
	cudaError cudaResult;

	//uint64_t nMasterIteration = 0;
	*Data->host.nProcessedInstances = 0;
	*Data->host.nProcessedIterations = 0;

	if (cudaSuccess != cudaMemcpy(Data->dev.nProcessedInstances, Data->host.nProcessedInstances, 8, cudaMemcpyHostToDevice)) {
		std::cout << "Error-Line--" << __LINE__ << std::endl;
	}
	const int nMnemoShowLen = MAX_ADAPTIVE_BASE_POSITIONS * 9 + MAX_ADAPTIVE_BASE_POSITIONS;
	char strMnemoShow[nMnemoShowLen] = {0};
	int16_t digitShow[MAX_ADAPTIVE_BASE_POSITIONS];
	uint64_t nUniversalProcessed = 0;

	do
	{
		//Set Master Iteration
		if (cudaSuccess != cudaMemcpy(Data->dev.nProcessedIterations, Data->host.nProcessedIterations, 8, cudaMemcpyHostToDevice)) {
			std::cout << "Error-Line--" << __LINE__ << std::endl;
		}

		//Zero Previous Count
		*Data->host.nProcessedInstances = 0;
		if (cudaSuccess != cudaMemcpy( Data->dev.nProcessedInstances, Data->host.nProcessedInstances, 8, cudaMemcpyHostToDevice)) {
			std::cout << "Error-Line--" << __LINE__ << std::endl;
		}

		printf("Iteration: %llu started.\r\n", *Data->host.nProcessedIterations + 1);
		IncrementAdaptiveDigits(host_AdaptiveBaseDigitCarryTrigger, host_AdaptiveBaseCurrentBatchInitialDigits
			, nUniversalProcessed, digitShow);
		ShowAdaptiveStr(digitShow, strMnemoShow);
		printf("<FROM> * * * * * *\t %s </FROM> (%llu)\r\n", strMnemoShow, nUniversalProcessed+1);




		if (Stride->startDictionaryAttack(Config->cuda_grid, Config->cuda_block) != 0) {
			std::cerr << "Error START!!" << std::endl;
			return false;
		}
		tools::start_time();


		float delay;
		if (Stride->endDictionaryAttack() != 0) {
			std::cerr << "Error END!!" << std::endl;
			return false;
		}
		tools::stop_time_and_calc_sec(&delay);

		//if (bCfgSaveResultsIntoFile) {
		//	save_thread = std::thread(&tools::saveResult, (char*)Data->host.mnemonic, (uint8_t*)Data->host.hash160, Data->wallets_in_round_gpu, Data->num_all_childs, Data->num_childs, Config->generate_path);
		//}



		if (cudaSuccess != cudaMemcpy(Data->host.nProcessedInstances, Data->dev.nProcessedInstances, 8, cudaMemcpyDeviceToHost)) {
			std::cout << "Error-Line--" << __LINE__ << std::endl;
		}

		nUniversalProcessed += *Data->host.nProcessedInstances;
		//printf("\t\t\t.\r\n\t\t\t.\r\n\t\t\t.\r\n");
		IncrementAdaptiveDigits(host_AdaptiveBaseDigitCarryTrigger, host_AdaptiveBaseCurrentBatchInitialDigits
			, nUniversalProcessed-1, digitShow);
		ShowAdaptiveStr(digitShow, strMnemoShow);

		printf("<UPTO> * * * * * * \t %s </UPTO> (%llu)\r\n", strMnemoShow, nUniversalProcessed);

		printf("Checking results of %llu checkups.\r\n", *Data->host.nProcessedInstances);


		//std::cout << std::endl << "PROCESSED: at " << tools::formatPrefix((double)*Data->host.nProcessedInstances / delay) << " COMBO/Sec" << std::endl;


		std::cout << "Iteration " << *Data->host.nProcessedIterations
			<< " completed we have processed  " << *Data->host.nProcessedInstances << " COMBOs  at " << tools::formatPrefix((double)*Data->host.nProcessedInstances / delay) << " COMBO/Sec" << std::endl;

		if (DictionaryCheckFound(Data->host.ret)) {
			tools::checkResult(Data->host.ret);
			playAlert();
		}

		++*Data->host.nProcessedIterations;
	} while (*Data->host.nProcessedIterations < nIterationsNeeded);//trunk

	return true;
}


bool InitalSync(ConfigClass* Config)
{
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] = 0;
	host_EntropyNextPrefix2[PTR_AVOIDER] = 0;

	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[0]) << 53;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[1]) << 42;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[2]) << 31;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[3]) << 20;
	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[4]) << 9;

	host_EntropyAbsolutePrefix64[PTR_AVOIDER] |= (uint64_t)(Config->words_indicies_mnemonic[5]) >> 2;
	host_EntropyNextPrefix2[PTR_AVOIDER] = (uint64_t)(Config->words_indicies_mnemonic[5]) << 62; //two bits from main 6 words


	size_t copySize;
	cudaError_t cudaResult;

	copySize = sizeof(uint64_t);
	cudaResult = cudaMemcpyToSymbol(dev_EntropyAbsolutePrefix64, host_EntropyAbsolutePrefix64, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_EntropyAbsolutePrefix64 failed!: " << cudaResult << std::endl;
		return false;
	}

	copySize = sizeof(uint64_t);
	cudaResult = cudaMemcpyToSymbol(dev_EntropyNextPrefix2, host_EntropyNextPrefix2, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_EntropyBatchNext24 failed!: " << cudaResult << std::endl;
		return false;
	}


	copySize = sizeof(int16_t) * MAX_ADAPTIVE_BASE_POSITIONS * MAX_ADAPTIVE_BASE_VARIANTS_PER_POSITION;
	cudaResult = cudaMemcpyToSymbol(dev_AdaptiveBaseDigitSet, host_AdaptiveBaseDigitSet, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "dev_AdaptiveBaseCurrentBatchInitialDigits copying " << copySize << " bytes to dev_AdaptiveBaseDigitSet failed!: " << cudaResult << std::endl;
		return false;
	}

	copySize = sizeof(host_AdaptiveBaseDigitCarryTrigger[0]) * MAX_ADAPTIVE_BASE_POSITIONS;
	cudaResult = cudaMemcpyToSymbol(dev_AdaptiveBaseDigitCarryTrigger, host_AdaptiveBaseDigitCarryTrigger, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_AdaptiveBaseDigitCarryTrigger failed!: " << cudaResult << std::endl;
		return false;
	}

	copySize = sizeof(int16_t) * MAX_ADAPTIVE_BASE_POSITIONS;
	cudaResult = cudaMemcpyToSymbol(dev_AdaptiveBaseCurrentBatchInitialDigits, host_AdaptiveBaseCurrentBatchInitialDigits, copySize, 0, cudaMemcpyHostToDevice);
	if (cudaResult != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol copying " << copySize << " bytes to dev_AdaptiveBaseCurrentBatchInitialDigits failed!: " << cudaResult << std::endl;
		return false;
	}

	return true;
}
