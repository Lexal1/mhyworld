class_name MarkovChain extends RefCounted
## Word-level Markov chain. Learns which word follows each run of `order` words in a text,
## then random-walks that to write new sentences. Read-only after _init, so it's safe to share.

const CLOSING_CHARS := "\"')]”’»"

static var _cache := {} # "path|order" -> MarkovChain

var order: int
var _next := {}                 # context (words joined by " ") -> Array of words seen after it
var _starts: Array[String] = [] # contexts that begin a sentence


## Shared per file, so every occupant using the same text only builds the chain once.
static func load_file(path: String, p_order := 2) -> MarkovChain:
	var key := "%s|%d" % [path, p_order]
	if not _cache.has(key):
		var text := ""
		if FileAccess.file_exists(path):
			text = FileAccess.get_file_as_string(path)
		else:
			push_error("MarkovChain: no text file at '%s'" % path)
		_cache[key] = MarkovChain.new(text, p_order)
	return _cache[key]


func _init(text: String, p_order := 2) -> void:
	order = maxi(p_order, 1)
	var words := text.replace("\r", " ").replace("\n", " ").replace("\t", " ").split(" ", false)
	for i in range(words.size() - order):
		var context := " ".join(words.slice(i, i + order))
		if not _next.has(context): _next[context] = []
		_next[context].push_back(words[i + order])
		if i == 0 or ends_sentence(words[i - 1]): _starts.push_back(context)


func is_empty() -> bool: return _starts.is_empty()


## Writes one line. It stops at the first sentence end after `min_words`, or is cut off at `max_words`.
func generate(min_words := 6, max_words := 24) -> String:
	if _starts.is_empty(): return ""
	var context: String = _starts.pick_random()
	var words := PackedStringArray()
	words.append_array(context.split(" "))
	while words.size() < max_words:
		if words.size() >= min_words and ends_sentence(words[-1]): break
		var options: Array = _next.get(context, [])
		if options.is_empty(): break # ran off the end of the source text
		words.push_back(String(options.pick_random()))
		context = " ".join(words.slice(words.size() - order))
	var line := " ".join(words)
	return line if ends_sentence(line) else line.rstrip(",;:- ") + "."


static func ends_sentence(word: String) -> bool:
	var w := word.rstrip(CLOSING_CHARS)
	return w.ends_with(".") or w.ends_with("!") or w.ends_with("?")
