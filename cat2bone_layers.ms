/*CAT2BONE MaxScript [Author: Ricky van den Waardenburg - 10/07/2017]
Finds nearest 1:1 mapping for bone<-CAT and applies position and rotation constraints.
Usage: select source layer containing CAT rig & target layer containing bone hierarchy and press 'apply constraints'
*/
try(DestroyDialog catboneRollout)catch()

layerList = #()
catLayerList = #()
boneLayerList = #()

rollout catboneRollout "CAT2BONE" width:392
(
	/*Local variables*/
	local selectedSourceLayer = undefined
	local selectedTargetLayer = undefined
	local fingerStringArray = #("mid", "ring", "pinky", "index", "finger", "thumb")

	/*User interface*/
	group "Source and target:"
	(
		label 'sourceLabel' "Source layer (CAT)" align:#left
		dropDownList 'sourceDropdownList' "" align:#left items:layerList
		label 'targetLabel' "Target layer (bones)" align:#left
		dropDownList 'targetDropdownList' "" align:#left items:layerList
	)

	group "Settings:"
	(
		checkBox 'ignoreDummies' "Ignore dummy objects" checked:false align:#left
		checkBox 'ignoreHubs' "Ignore hub objects" checked:false align:#left
		checkBox 'disableInsideCheck' "Disable inside check" checked:true align:#left
		checkBox 'ignoreFingerPositionConstraint' "Disable position constraints for finger bones" checked:true align:#left
		spinner 'boneOffset' "Bone offset: " fieldWidth:30 type:#float range:[0,1,0] align:#left
	)


	group "Run script:"
	(
		progressBar 'progressBar' "ProgressBar" width:360 align:#left
		button 'processButton' "Apply constraints" align:#right
	)

	/*Initializing drop-down lists*/
	on catboneRollout open do
	(
		print ("Initializing layer dropdown lists.")
		if (LayerManager.count > 0) then (
			for i = 1 to LayerManager.count - 1 do (
				layerName =  (LayerManager.getLayer i).name
				print ("Adding layer to list: " + layerName)
				layer = (LayerManager.getLayer i)
				layer.nodes &layerNodes
				
				/*Check if we have valid objects in the layer*/
				boneLayerObjects = for boneObject in layerNodes where (classof boneObject == BoneGeometry) collect boneObject
				catLayerObjects = for catObject in layerNodes where (classof catObject == CATBone or (classof catObject == HubObject and ignoreHubs.checked == false) or (classof catObject == Dummy and ignoreDummies.checked == false)) collect catObject
					
				if  boneLayerObjects.count > 0 then
				(
					append boneLayerList layerName
				)
				if  catLayerObjects.count > 0 then
				(
					append catLayerList layerName
				)
			)
		)

		sourceDropdownList.items = catLayerList
		targetDropdownList.items = boneLayerList
		
		print ("Source layer:" + sourceDropdownList.selected)
		selectedSourceLayer = sourceDropdownList.selected
		print ("Target layer:" + targetDropdownList.selected)
		selectedTargetLayer = targetDropdownList.selected
	)
	
	/*Force redraw on close, just in case.*/
	on catboneRollout close do
	(
		/*Re-enable scene redraw*/
		enablesceneredraw()
		redrawviews()
	)

	/*Update source dropdown list selection*/
	on sourceDropdownList selected sel do
	(
		print ("Source layer:" + sourceDropdownList.selected)
		selectedSourceLayer = sourceDropdownList.selected
	)

	/*Update target dropdown list selection*/
	on targetDropdownList selected sel do
	(
		print ("Target layer:" + targetDropdownList.selected)
		selectedTargetLayer = targetDropdownList.selected
	)

	/*Main logic*/
	on processButton pressed do
	(
		/*Early out if source/target layer are undefined.*/
		if selectedSourceLayer == undefined or selectedTargetLayer == undefined then
		(
			print ("[CAT2BONE] Selected source or target layer is undefined.")
			return false
		)

		/*Get objects in selected layers*/
		local sourceLayer = LayerManager.getLayerFromName selectedSourceLayer
		local targetLayer = LayerManager.getLayerFromName selectedTargetLayer

		sourceLayer.nodes &sourceNodes
		targetLayer.nodes &targetNodes

		/*Check if layers are not empty*/
		if sourceNodes.count == 0 or targetNodes.count == 0 then
		(
			print ("[CAT2BONE] Selected source or target layer has no nodes.")
			return false
		)

		/*Filter out invalid objects from layers*/
		sourceNodes = for catObject in sourceNodes where (classof catObject == CATBone or (classof catObject == HubObject and ignoreHubs.checked == false) or (classof catObject == Dummy and ignoreDummies.checked == false))  collect catObject
		targetNodes = for boneObject in targetNodes where (classof boneObject == BoneGeometry) collect boneObject

		/*Check if layers are not empty after removing nodes*/
		if sourceNodes.count == 0 or targetNodes.count == 0 then
		(
			print ("[CAT2BONE] Selected source or target layer has no (valid) nodes.")
			return false
		)

		/*Find best matches from bone to CAT rig*/
		print("[CAT2BONE] Applying constraints from bones to CAT rig")

		local num = 1
		progressBar.value = 0

		local progressPerNode = (100.0 / targetNodes.count)

		/*Disable scene redrawing for speed*/
		disablesceneredraw()

		/*O(n*m)*/
		for boneObject in targetNodes do
		(
			local bestCATMatch = undefined
			local bestScore = 100000000000000.0

			/*Loop through CAT rig layer*/
			for catObject in sourceNodes do
			(
				/*Transform local-space bounding box of CAT node to local-space of bone node*/
				bbox = #()

				local catRotationMatrix = inverse (rotate (matrix3 1) (catObject.transform))
				for i in nodeLocalBoundingBox catObject do append bbox i

				/*
				Score heuristic: lowest distance from bone position to CAT object position
				Calculate distance from CAT object position to bone object position
				*/
				local currentScore = distance catObject.transform.pos boneObject.transform.pos

				/*Score mapping of bone -> CAT object based distance and if the bone's center is inside the bbox or not.*/
				if (currentScore < bestScore) then
				(
					/*Get 'bone direction' (bone origin to bone center)*/
					local boneRotation = normalize(boneObject.transform.pos - boneObject.center)

					/*Calculate bone position offset by 0.1 in the 'bone direction'*/
					local boneCenter = boneObject.transform.pos - boneRotation * (boneObject.length * boneOffset.value)

					/*Transform bbox and bone position into bbox-space*/
					for i in 1 to bbox.count do bbox[i] *= catRotationMatrix
				    boneCenter *= catRotationMatrix

					if (disableInsideCheck.checked == true) then
					(
						bestCATMatch = catObject
						bestScore = currentScore
						continue
					)
					
					/*Check if bone position is inside bounding box*/
					if 	(bbox[1].x <= boneCenter.x and boneCenter.x <= bbox[2].x) AND \
						(bbox[1].y <= boneCenter.y and boneCenter.y <= bbox[2].y) AND \
						(bbox[1].z <= boneCenter.z and boneCenter.z <= bbox[2].z)
					then
					(
						bestCATMatch = catObject
						bestScore = currentScore
					)
				)
			)

			/*No match found, skip to next bone*/
			if bestCATMatch == undefined then
			(
				print("[CAT2BONE] No match found for bone: " + boneObject.name)
				continue
			)

			print("[CAT2BONE] Mapping bone: " + boneObject.name + " to CAT object: " + bestCATMatch.name)

			/*Initialize orientation constraint*/
			orientationConstraint = Orientation_Constraint relative:true
			orientationConstraint.appendTarget bestCATMatch 50.0

			rotController = boneObject.rotation.controller

			/*
			Uncomment this for debug printing.
			print("[CAT2BONE] Rotation controller class: " + (classof rotController as string))
			*/

			if (classof rotController == Rotation_List) then
			(
				/*Remove all rotation constraints from the rotation list and replace them with the new orientation constraint.*/
				for x = 1 to rotController.count do
				(
					/*
					Uncomment this for debug printing.
					print("[CAT2BONE] List element: " + (rotController[x].name as string))
					*/
					if (classof rotController[x].controller == Orientation_Constraint) then
					(
						rotController.delete x
					)
				)
				rotController[rotController.count+1].controller = orientationConstraint
				--rotController[rotController.count+1].controller.setActive 1
				rotController.setActive rotController.count
			)
			else
			(
				/*Otherwise create a rotation list, add the default controller to the list, then add the new orientation constraint.*/
				local rotList = Rotation_List()
				boneObject.rotation.controller = rotList
				rotList[2].controller = orientationConstraint
				boneObject.rotation.controller.setActive rotList.count

				/*
				Uncomment this for debug printing.
				for x = 1 to rotList.count do
				(
					print("[CAT2BONE] List element: " + (rotList[x].name as string))
				)
				*/
			)
			
			/*Update progress bar*/
			num = num + 1
			progressBar.value = progressPerNode * num
			
			if (ignoreFingerPositionConstraint.checked == true) then
			(
				local isFinger = false
				
				/*If this bone is classified as a finger -> don't apply position constraint*/
				for fingerName in fingerStringArray do
				(
					if (findString boneObject.name fingerName != undefined) then 
					(
						isFinger = true
					)
				)
				
				/*Skip finger bone*/
				if (isFinger == true) then
				(	
					print("[CAT2BONE] Not applying position constraint for finger bone: " + boneObject.name)					
					continue
				)
			)
			
			/*Initialize position constraint*/
			positionConstraint = Position_Constraint relative:true
			positionConstraint.appendTarget bestCATMatch 50.0

			posController = boneObject.position.controller

			/*
			Uncomment this for debug printing.
			print("[CAT2BONE] Position controller class: " + (classof posController as string))
			*/
		
			if (classof posController == Position_List) then
			(
				/*Remove all position constraints from the position list and replace them with the new position constraint.*/
				for x = 1 to posController.count do
				(
					/*
					Uncomment this for debug printing.
					print("[CAT2BONE] List element: " + (posController[x].name as string))
					*/

					if (classof posController[x].controller == Position_Constraint) then
					(
						posController.delete x
					)
				)

				posController[posController.count+1].controller = positionConstraint
				posController.setActive posController.count
			)
			else
			(
				/*Otherwise create a position list, add the default controller to the list, then add the new position constraint.*/
				local posList = Position_List()
				boneObject.position.controller = posList
				posList[2].controller = positionConstraint
				boneObject.position.controller.setActive posList.count
			--	posList[2].controller.setActive 1
				/*
				Uncomment this for debug printing.
				for x = 1 to posList.count do
				(
					print("[CAT2BONE] List element: " + (posList[x].name as string))
				)
				*/
			)

		)

		/*Re-enable scene redraw*/
		enablesceneredraw()
		redrawviews()

		/*Reset progressbar*/
	    progressBar.value = 0

		messageBox "Finished applying constraints."
		print ("[CAT2BONE] Finished applying constraints.")
	)

)

CreateDialog catboneRollout
