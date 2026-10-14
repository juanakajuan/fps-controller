class_name Points
extends RefCounted

signal changed(balance: int)

var balance: int = 500
var earned: int = 0


func earn(amount: int) -> void:
	balance += amount
	earned += amount
	changed.emit(balance)


## Returns false and changes nothing if the balance is too small.
func spend(amount: int) -> bool:
	if balance < amount:
		return false
	balance -= amount
	changed.emit(balance)
	return true
