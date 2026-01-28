extends Node

enum Bus{
	MASTER,SFX,BGM,
}
const BGM_BUS = "BGM"
const SFX_BUS = "SFX"

#音乐播放器个数
var music_audio_player_count :int = 2
var current_music_player_index :int = 0
var music_player_list : Array[AudioStreamPlayer]

#音效播放器个数
var sfx_audio_player_count :int = 6
var current_sfx_player_index :int = 0
var sfx_player_list : Array[AudioStreamPlayer]

# BGM渐变时长
var music_fade_duration:float = 1.0

func _ready() -> void:
	print("声音单例加载完毕")
	init_BGM_audio_manager()
	init_SFX_audio_manager()

func init_BGM_audio_manager()->void:
	for i in music_audio_player_count:
		var audio_player := AudioStreamPlayer.new()
		audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
		audio_player.bus = BGM_BUS
		add_child(audio_player)
		music_player_list.append(audio_player)

func init_SFX_audio_manager()->void:
	for i in sfx_audio_player_count:
		var audio_player := AudioStreamPlayer.new()
		audio_player.bus = SFX_BUS
		add_child(audio_player)
		sfx_player_list.append(audio_player)

# 播放BGM
func play_BGM(_audio : AudioStream)->void:
	var current_player := music_player_list[current_music_player_index]
	if current_player.stream == _audio:
		return
	var empty_audio_player_index = 0 if current_music_player_index==1 else 1
	var empty_player = music_player_list[empty_audio_player_index]
	fade_out_stop(current_player)
	empty_player.stream = _audio
	play_fade_in(empty_player)
	current_music_player_index = empty_audio_player_index
#渐入
func play_fade_in(_audio_player : AudioStreamPlayer)->void:
	_audio_player.play()
	var tween:Tween = create_tween()
	tween.tween_property(_audio_player,"volume_db",0,music_fade_duration)
#渐出
func fade_out_stop(_audio_player : AudioStreamPlayer)->void:
	var tween:Tween = create_tween()
	tween.tween_property(_audio_player,"volume_db",-40,music_fade_duration)
	await tween.finished
	_audio_player.stop()
	_audio_player.stream = null

# 播放音效
func play_SFX(_audio : AudioStream)->void:
	for i in sfx_audio_player_count:
		var sfx_audio_player := sfx_player_list[i]
		if not sfx_audio_player.playing:
			sfx_audio_player.stream = _audio
			sfx_audio_player.play()
			break

func set_volume(bus_index:Bus, v:float)->void:
	var db := linear_to_db(v)
	AudioServer.set_bus_volume_db(bus_index, db)
