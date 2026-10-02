class_name TaskManager extends RefCounted

### TaskManager is used to automatically manage jobs where you don't really care about whether they've finished yet
### or not. For example, this is used for chunk generation at the moment. (though the purpose of
### this class may be changed in the future.)

var _unfinished_thread_tasks: Array[int] = []

func add_task(tid: int) -> void:
	_unfinished_thread_tasks.push_back(tid)

func wait_for_tasks():
	var newUnfinishedTasks: Array[int] = []
	for task in _unfinished_thread_tasks:
		#WorkerThreadPool.wait_for_task_completion(task)
		if WorkerThreadPool.is_task_completed(task):
			var err = WorkerThreadPool.wait_for_task_completion(task) # this is needed so godot frees up the resources properly
			match err:
				OK:
					print("[wait_for_tasks] Task %d completed" % task)
					continue
				ERR_INVALID_PARAMETER:
					printerr("[wait_for_tasks] Task %d doesn't exist" % task)
				ERR_BUSY:
					printerr("[wait_for_tasks] Busy task: %d" % task)
		else:
			newUnfinishedTasks.push_back(task)
	_unfinished_thread_tasks = newUnfinishedTasks

func force_wait_for_tasks():
	for task in _unfinished_thread_tasks:
		WorkerThreadPool.wait_for_task_completion(task) # TODO: handle Error exit
	_unfinished_thread_tasks = []
