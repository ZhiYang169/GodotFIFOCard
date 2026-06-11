extends Node

@export var debug_enable : Bool = true

func debug(msg) -> void:
    if debug_enable :
        print_rich("[color=read][DEBUG][/color]",msg)

func log(msg) -> void:
    print(msg)