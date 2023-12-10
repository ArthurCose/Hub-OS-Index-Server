<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.10.2" name="warp" tilewidth="50" tileheight="32" tilecount="5" columns="5" objectalignment="top">
 <image source="warp.png" width="250" height="32"/>
 <tile id="1">
  <objectgroup draworder="index" id="2">
   <object id="1" x="5" y="3" width="40" height="25">
    <ellipse/>
   </object>
  </objectgroup>
  <animation>
   <frame tileid="1" duration="300"/>
   <frame tileid="2" duration="100"/>
   <frame tileid="3" duration="100"/>
   <frame tileid="4" duration="400"/>
   <frame tileid="3" duration="100"/>
   <frame tileid="2" duration="100"/>
  </animation>
 </tile>
</tileset>
