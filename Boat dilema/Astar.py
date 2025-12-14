import json
from math import sqrt
import heapq


with open(r"C:\Users\anuva\Downloads\Demos\Boat dilema\map_1.json", "r") as f:
    data = json.load(f)
#loads file

start = (data["startPos"][0] - 1, data["startPos"][1] - 1)
goal  = (data["finishPos"][0] - 1, data["finishPos"][1] - 1)
#stores mat lab coordsinates in tuples after turning them to 0 base as txt says they are 1 based

windSpeed = data["windSpeed"]
windDir = data["windDir"]

rows = len(data["windDir"])
columns = len(data["windDir"] [0])
#determine number of rows and columns

currentPos = start
currentHeading = 0
#defult position

def positionChange(headingAngle, currentPos):
    direction = headingAngle % 360
#change position based on heading angle reduced mod to be in range of 360
#each angle is unifrom to the grid 
    if direction == 0:
        return (currentPos[0] - 1, currentPos[1])      
    elif direction == 60:
        return (currentPos[0] - 1, currentPos[1] + 1)  
    elif direction == 120:
        return (currentPos[0] + 1, currentPos[1] + 1)  
    elif direction == 180:
        return (currentPos[0] + 1, currentPos[1])      
    elif direction == 240:
        return (currentPos[0] + 1, currentPos[1] - 1)  
    elif direction == 300:
        return (currentPos[0] - 1, currentPos[1] - 1)  


def inBounds(row, col):
    if 0<= row < rows and 0<= col < columns:
        return True
    else:
        return False
#used to check if move is legally in bound

def polarFactor(angle):
#returns multiplier value for speed based on heading angle
#copied the function from the txt
    if 30 <= angle < 60:
        return 1.0       
    elif 60 <= angle < 90:
        return 0.95      
    elif 90 <= angle < 135:
        return 0.85      
    elif 135 <= angle <= 180:
        return 0.70      
    else:
        return 0

def penalty(heading, newHeading):
#time penalty for change in angle
#copied from the txt
    d = abs((heading-newHeading))
    d = min(d, 360-d)
    #wrap the angle to get it less then 180
    if d == 0:
        tp = 0
    elif d <= 10:
        tp = 0.5
    elif d <= 20:
        tp = 1.0
    elif d <= 30:
        tp = 1.5
    elif d <= 40:
        tp = 2.0
    elif d <= 50:
        tp = 2.5
    elif d <= 60:
        tp = 3.0
    else:
        tp = 4.0
    return tp

def timeFinder(currentPos, currentHeading, nextHeading, windSpeed, windDir):
    y=currentPos[0]
    x=currentPos[1]
    allowed=True

    localSpeed = windSpeed[y][x]
    #speed of wind at given cell
    nextWindDir = (windDir[y][x] + 180) % 360
    nextWindDir = min(360-nextWindDir,nextWindDir)
    
    relativeAngle = abs(nextHeading - nextWindDir)
    relativeAngle = min(360-relativeAngle, relativeAngle)
    #return relative angle of boat to the wind direction

    if relativeAngle<30:
        allowed=False
    #prevent boat from moving if relative angle is too low as stated by the txt

    factor = polarFactor(relativeAngle)
    speed = localSpeed * factor
    if speed == 0:
        allowed=False
    #uses speed factor to calculate boat speed at given cell
    #again from the txt

    timePenalty = penalty(currentHeading, nextHeading)
    if speed == 0:
        allowed=False
    else:
        timeTaken = 10/(speed) + timePenalty
    #same equation used by the txt it gives us the final time value for travel to the next unit

    if allowed==False:
        return None
    else:
        return timeTaken,speed,relativeAngle
    #final return which gives us the time speed and angle
    

#--------A*---------#
#https://www.datacamp.com/tutorial/a-star-algorithm
#I used this site to base my algorithm, I have simply adapted it to suit this need
#I used videos https://www.youtube.com/watch?v=W9zSr9jnoqY
#As well as one which was about Djykstras explaining heapq

def heurisitc(currentPos, nextPos):
    return sqrt((currentPos[0]-nextPos[0])**2+(currentPos[1]-nextPos[1])**2)
#simple herustic that finds distance from end to start using pythagorus


def algorithm(start, goal):
    g = {}
    h = {}
    f = {}
    parent = {}
    heading = {}

    openList = []
    closedList = set()
    cardinal = [0, 60, 120, 180, 240, 300]
    #creates the visted and to vist lists aswell as the cardinal movements

    g[start] = 0
    h[start] = heurisitc(start, goal)
    f[start] = g[start] + h[start]
    parent[start] = None
    heading[start] = 0 
    
    heapq.heappush(openList, (f[start], start))
    #moves the smallest item with lowest f[start] which is the heuristic + distance moved and adds its position in this case start

    while openList:
        currentF, current = heapq.heappop(openList)
        
        if current in closedList:
            continue
        #as we are using heapq the priority list will always give the shortest distance first
        if current == goal:
            return path(parent, current)
        # if we have reached the goal we return the traced path back
       

        closedList.add(current)

        for i in cardinal:
            coords = positionChange(i, current)
            if coords in closedList:
                continue
            #if we already checked the node we skip it
            if not inBounds(coords[0],coords[1]):
                continue

            output = timeFinder(current, heading[current], i, windSpeed, windDir)
            if output is None:
                continue
            time, speed, angle = output
            score = time+g[current]

            if coords not in g or score < g[coords]:
                g[coords] = score #stores the best score for the cell
                h[coords] = heurisitc(coords, goal) # stores the next heurisitc with coords
                f[coords] = g[coords] +h[coords] # gives the nodes priority
                parent[coords] = current #stores the current node for the path function 
                heading[coords] = i #stores the angle of the next node
                heapq.heappush(openList, (f[coords], coords))
                #stores the new node in the open list, heapq orders it based on priority

#def timeFinder(currentPos, currentHeading, nextHeading, windSpeed, windDir):

def path(parent, current):
    path = []
    while current is not None:
        path.append(current)
        current = parent[current]
    path.reverse()
    return path

result = algorithm(start, goal)

result = algorithm(start, goal)
directions = []

for i in range(1, len(result)):
    y1, x1 = result[i-1]
    y2, x2 = result[i]
    
    dy = y2 - y1
    dx = x2 - x1

    if dy == -1 and dx == 0:
        directions.append("N")
    elif dy == -1 and dx == 1:
        directions.append("NE")
    elif dy == 0 and dx == 1:
        directions.append("E")
    elif dy == 1 and dx == 1:
        directions.append("SE")
    elif dy == 1 and dx == 0:
        directions.append("S")
    elif dy == 1 and dx == -1:
        directions.append("SW")
    elif dy == 0 and dx == -1:
        directions.append("W")
    elif dy == -1 and dx == -1:
        directions.append("NW")

print(directions)