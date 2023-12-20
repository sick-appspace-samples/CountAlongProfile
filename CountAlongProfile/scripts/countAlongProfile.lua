
--Start of Global Scope---------------------------------------------------------

-- Create and configure decorators
local passTeachDeco = View.ShapeDecoration.create():setLineColor(0, 255, 0)
passTeachDeco:setLineWidth(10):setFillColor(0, 255, 0, 128)
local failTeachDeco = View.ShapeDecoration.create():setLineColor(255, 0, 0)
failTeachDeco:setLineWidth(10):setFillColor(255, 0, 0, 128)

local risingEdgeDeco = View.ShapeDecoration.create()
risingEdgeDeco:setLineColor(59, 156, 208):setPointSize(40)

local fallingLineDeco = View.ShapeDecoration.create()
fallingLineDeco:setLineColor(242, 148, 0):setPointSize(40)

local graphDeco = View.GraphDecoration.create()
graphDeco:setDrawSize(5):setDynamicSizing(true)

local passTextDeco = View.TextDecoration.create()
passTextDeco:setPosition(50, 1500):setSize(70):setColor(0, 155, 0)
local failTextDeco = View.TextDecoration.create()
failTextDeco:setPosition(50, 1500):setSize(70):setColor(255, 0, 0)
local textDeco = View.TextDecoration.create()
textDeco:setPosition(20, 80):setSize(70):setColor(0, 0, 0)

-- Read images from the 'resources' directory
local IMAGE_PATH = 'resources/'

-- Create an image directory provider
local gImProvider = Image.Provider.Directory.create()
-- Define the path from which the provider gets images
Image.Provider.Directory.setPath(gImProvider, IMAGE_PATH)
-- Set the a cycle time of 500ms
Image.Provider.Directory.setCycleTime(gImProvider, 1000)
-- Set to only loop through images once
Image.Provider.Directory.setCyclicModeActive(gImProvider, false)
-- Make room for all sample images
Image.Provider.Directory.setImagePoolSizeMB(gImProvider, 26)

-- Create an image matcher
local gMatcher = Image.Matching.EdgeMatcher.create()

-- Creating viewers to display the results
local v1 = View.create('v1')
v1:clear()
local v2 = View.create('v2')
v2:clear()

--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

local function teachBox()
  ------------------------------------------------------------------------------
  -- The box of tea bags move around in the live images. One way of finding  the
  -- box is to set up an image matcher. We teach the matcher using part of the
  -- box lid and several of the tea bags. We extract a profile relative to the
  -- found box as a cross section of all the tea bags. To make sure that the
  -- extracted profile cover all tea bags we extract it over the tea bags, the
  -- box and enough space outside.
  ------------------------------------------------------------------------------
  gMatcher:setRotationRange(math.rad(30))
  gMatcher:setDownsampleFactor(3)

  local teachImage = Image.load('resources/Teach/teachImage.png')
  local teachRegion = Shape.createRectangle(Point.create(545, 936), 300, 700)
  gMatcher:teach(teachImage, teachRegion)

  v1:addImage(teachImage)
  v1:addText('Teach image', textDeco)
  v1:addShape(teachRegion, passTeachDeco)
  v1:present('ASSURED')
end

local function main()
  print('AppEngine Version: ' .. Engine.getVersion())

  -----------------------------------------------
  -- Find box of tea bags in teach image --------
  -----------------------------------------------
  teachBox()

  -----------------------------------------------
  -- Starting the image provider ----------------
  -----------------------------------------------
  Image.Provider.Directory.start(gImProvider)
end

--The following registration is part of the global scope which runs once after startup
--Registration of the 'main' function to the 'Engine.OnStarted' event
Script.register('Engine.OnStarted', main)
-- serve API in global scope

---This callback is called for every new image
---@param liveImage Image
---@param sensorData SensorData
local function handleNewImage(liveImage, sensorData)
  -----------------------------------------------
  -- Locate box of tea bags in live image -------
  -----------------------------------------------
  local pose, _, _ = gMatcher:match(liveImage)

  -----------------------------------------------
  -- Extract profile across box of tea bags
  -----------------------------------------------
  -- Create a vertical line segment which is translated to the position where the tea bag box is found
  local line = Shape.createLineSegment(Point.create(0, -700), Point.create(0, 500))
  local extractLine = line:transform(pose[1])
  local profile = Image.extractProfile(liveImage, extractLine, extractLine:getPerimeterLength())
  profile = profile:blur(3)

  -----------------------------------------------
  -- Segment the profile to find individual tea bags
  -----------------------------------------------
  local thresholdValueLow = 5500
  local thresholdValueHigh = 6500
  local segments = Profile.segment(profile, thresholdValueLow, thresholdValueHigh)
  local regions = Profile.IndexRegion.split(segments)

  ----------------------------------------------
  -- The number of tea bags is the number segments with a certain size
  -----------------------------------------------
  local numberOfTeaBags = 0
  local sums = Profile.getSum(profile, regions)
  for jj = 1, #sums do
    if (sums[jj] > 50000 and sums[jj] < 140000) then
      numberOfTeaBags = numberOfTeaBags + 1
    end
  end
  print('Number of tea bags: ' .. numberOfTeaBags)

  -----------------------------------------------
  -- Visualization ------------------------------
  -----------------------------------------------
  -- Show live image
  v1:clear()
  v1:addImage(liveImage)
  -- get the filename from the metadata
  local imgName = SensorData.getOrigin(sensorData)
  v1:addText('Live image:\n' .. imgName, textDeco)
  if numberOfTeaBags == 25 then
    v1:addText('Pass.\nNumber of tea bags: ' .. numberOfTeaBags, passTextDeco)
    v1:addShape(extractLine, passTeachDeco)
  else
    v1:addText('Fail.\nNumber of tea bags: ' .. numberOfTeaBags, failTextDeco)
    v1:addShape(extractLine, failTeachDeco)
  end
  v1:present('ASSURED')

  -- Show profile
  graphDeco:setTitle('Live image:\n' .. imgName)
  v2:addProfile(profile, graphDeco)
  local startIndex, stopIndex = Profile.IndexRegion.toStartStop(segments)
  for jj = 1, #startIndex do
    v2:addPoint(Point.create(startIndex[jj], thresholdValueLow), fallingLineDeco)
    v2:addPoint(Point.create(stopIndex[jj], thresholdValueLow), risingEdgeDeco)
  end
  v2:present('ASSURED')
end

-- Register image callback
Image.Provider.Directory.register(gImProvider, 'OnNewImage', handleNewImage)

--End of Function and Event Scope------------------------------------------------
