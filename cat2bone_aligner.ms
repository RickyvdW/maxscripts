/*CAT rig bone -> regular bone smart aligner MaxScript [Author: Ricky van den Waardenburg - 12/07/2017]
Aligns bone to CAT bone.
Usage: bind macro to a button combination, press button combination, select CAT bone -> select bone in order and the CAT bone will be aligned to the bone object.
*/
macroscript SmartBoneAligner tooltip:"CAT->Bone SmartAlign"
    category: "Scripts"
(
	fn pickFilter o = (classof o == BoneGeometry or classof o == CATBone or classof o == HubObject)

	on Execute do (

		/* Pick target bone/cat bone */
		local targets = #()
		append targets (pickObject count:2 filter:pickFilter)
		local intToAxis = #("X", "Y", "Z")

		/*Early out: no targets selected..*/
		if targets == undefined then
		(
			messageBox "No objects selected"
			return false
		)
		/*Early out: not enough objects selected..*/
		if targets.count < 2 then
		(
			messageBox "Less than two objects selected"
			return false
		)

		local catObject = targets[1]
		local boneObject = targets[2]

		print ("[SMARTALIGN] Bone position: " + boneObject.transform.pos as string)
		print ("[SMARTALIGN] CAT position: " + catObject.transform.pos as string)

		/*First move CAT bone to bone position*/
		local posOffset = (boneObject.transform.pos - catObject.transform.pos)
		move catObject posOffset

		/*Initialize rotation axes*/
		local boneAxes = #(boneObject.transform[1], boneObject.transform[2], boneObject.transform[3])
		local mappedAxes = #()

		print("[SMARTALIGN] Bone axes: " + boneAxes as string)

		/*Find best match for CAT object axis in bone axis (x-axis and y-axis)*/
		local rotFromAxis = 1
		local rotToAxis = 1

		local catXAxis = 1
		local catYAxis = 1

		local xRotDot = 0.0
		local yRotDot = 0.0

    /*Iterate over all 3 CAT bone axes*/
		for i = 1 to 3 do
		(
			local bestMatch = 1
			local bestDot = 0.0

			local dotProduct = abs (dot catObject.transform[i] boneAxes[1]) --X axis in bone-space
			local yDotProduct = abs (dot catObject.transform[i] boneAxes[2]) --Y axis in bone-space

      /*We have found an equivalent of the bone's x-axis in CAT bone space*/
			if (dotProduct > xRotDot and dotProduct >= yDotProduct) then
			(
				catXAxis = i
				xRotDot = dotProduct
				continue
			)

			/*We have found an equivalent of the bone's y-axis in CAT bone space*/
			if (yDotProduct > yRotDot and yDotProduct >= dotProduct) then
			(
				catYAxis = i
				yRotDot = dotProduct
				continue
			)
		)

		--Print best match: X-axis equivalent
		print("[SMARTALIGN] Best match for bone X-axis in CAT bone: " + intToAxis[catXAxis])
    --Print best match: Y-axis equivalent
		print("[SMARTALIGN] Best match for bone Y-axis in CAT bone: " + intToAxis[catYAxis])

		local dotFraction = 1.0 / 3.0

		local rotMatrix = matrix3 1

    --Target axis is the bone's x-axis (CAT bone axis -> bone x-axis)
    local targetAxis = boneObject.transform[1]
		local dotProduct = dot catObject.transform[catXAxis] boneObject.transform[1]
		local dotReverseToFraction = -1.0 + dotFraction * 2.0

		--Arbitrary axis is closest to -X
		if (dotProduct >= -1.0 and dotProduct < dotReverseToFraction) then
		(
			--Reverse mapped axis
			targetAxis = -boneObject.transform[1]
		)
    --Otherwise arbitrary axis is closest to X -> see targetAxis initialization

    --Rotate CAT object's arbitrary axis towards snapped X-axis
		transformMatrix = catObject.transform
		vec = normalize catObject.transform[catXAxis]
		dir = normalize targetAxis
		rotationMatrix = angleaxis (acos (dot vec dir)) (normalize (cross dir vec))
		catObject.transform = translate (rotate (scalematrix transformMatrix.scale) (transformMatrix.rotation * rotationMatrix)) transformMatrix.pos

		--Get bone Y, -Y, Z or -Z axis depending on which rotation is the shortest with respect to cat bone's Y axis
		finalAxes = #(boneObject.transform[2], -boneObject.transform[2], boneObject.transform[3], -boneObject.transform[3])

    --Find best match (in bone space) for CAT bone's y-axis equivalent
		local bestMatch = 1
		local bestDot = -1.0
		for j = 1 to finalAxes.count do
		(
			local dotProduct = dot catObject.transform[catYAxis] finalAxes[j]
			if dotProduct >= bestDot then
			(
				bestMatch = j
				bestDot = dotProduct
			)
		)

    --Rotate CAT object's arbitrary axis towards snapped Y-axis
		tm = catObject.transform
		vec = normalize catObject.transform[catYAxis]
		dir = normalize finalAxes[bestMatch]
		rtm = angleaxis (acos (dot vec dir)) (normalize (cross dir vec))
		catObject.transform = translate (rotate (scalematrix tm.scale) (tm.rotation*rtm)) tm.pos
	)
)
