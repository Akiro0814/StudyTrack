package com.repea.studytrack.ui.parity

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.unit.dp
import kotlin.math.*

/** Line/filled tab symbols rebuilt on the shared 24-point optical grid. */
@Composable fun StudyTabGlyph(index: Int,selected: Boolean,color: Color) {
    Canvas(Modifier.size(24.dp)) {
        withTransform({ scale(size.width/24,size.height/24,pivot=Offset.Zero) }) {
            val stroke = Stroke(1.65f,cap=StrokeCap.Round,join=StrokeJoin.Round)
            when(index) {
                0 -> { val p=Path().apply { fillType=PathFillType.EvenOdd; moveTo(2.5f,10.8f); lineTo(12f,2.8f); lineTo(21.5f,10.8f); lineTo(19.3f,10.8f); lineTo(19.3f,21f); lineTo(4.7f,21f); lineTo(4.7f,10.8f); close(); addRect(Rect(9.2f,14f,14.8f,21f)) }; drawPath(p,color,style=if(selected) Fill else stroke) }
                1 -> { for(i in 0..2) { val x=3f+i*6.3f; val top=if(i==1) 3f else 4.5f; drawRoundRect(color,Offset(x,top),Size(4.4f,18.5f-top),CornerRadius(1.1f),style=if(selected) Fill else stroke); drawLine(if(selected) Color.White.copy(alpha=0.7f) else color,Offset(x+1,top+3),Offset(x+3.4f,top+3),0.9f) } }
                2 -> { drawPath(Path().apply { moveTo(3f,3f); lineTo(3f,21f); lineTo(22f,21f) },color,style=stroke); drawPath(Path().apply { moveTo(5f,16f); lineTo(10f,11f); lineTo(14f,14f); lineTo(21f,6f) },color,style=stroke); for(p in listOf(Offset(5f,16f),Offset(10f,11f),Offset(14f,14f),Offset(21f,6f))) drawCircle(color,1.4f,p) }
                else -> { val p=Path().apply { fillType=PathFillType.EvenOdd; for(i in 0 until 32) { val r=if(i%4==1 || i%4==2) 10.7 else 8.7; val angle=i*PI/16; val x=12+cos(angle)*r; val y=12+sin(angle)*r; if(i==0) moveTo(x.toFloat(),y.toFloat()) else lineTo(x.toFloat(),y.toFloat()) }; close(); addOval(Rect(8f,8f,16f,16f)) }; drawPath(p,color,style=if(selected) Fill else stroke) }
            }
        }
    }
}
