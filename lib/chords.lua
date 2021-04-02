local chords = {{
    name = "Major",
    intervals = {0, 4, 7}
}, {
    name = "Major 6th",
    intervals = {0, 4, 7, 9}
}, {
    name = "Major 6th",
    intervals = {0, 4, 7, 11}
}, {
    name = "Major 7th (b5)",
    intervals = {0, 4, 6, 11}
}, {
    name = "Major 7th (#5)",
    intervals = {0, 4, 8, 11}
}, {
    name = "Dominant 7th",
    intervals = {0, 4, 7, 10}
}, {
    name = "Major 9th",
    intervals = {0, 2, 4, 7, 11}
}, {
    name = "Minor",
    intervals = {0, 3, 7}
}, {
    name = "Minor 6th",
    intervals = {0, 3, 7, 9}
}, {
    name = "Minor 7th",
    intervals = {0, 3, 7, 10}
}, {
    name = "Minor 7th (b5)",
    intervals = {0, 3, 6, 10}
}, {
    name = "Diminished 7th",
    intervals = {0, 3, 6, 9}
}, {
    name = "Minor 9th",
    intervals = {0, 2, 3, 7, 10}
}, {
    name = "Minor 11th",
    intervals = {0, 2, 3, 5, 7, 10}
}}


for i, chord in ipairs(chords) do
    chord.name = chord.name .. " Chord"
    table.insert(musicUtil.SCALES, chord)
end
