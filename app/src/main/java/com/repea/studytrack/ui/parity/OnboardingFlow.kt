@file:OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
package com.repea.studytrack.ui.parity

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.animation.core.tween
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import com.repea.studytrack.domain.*
import com.repea.studytrack.repository.PlatformState
import com.repea.studytrack.viewmodel.PlatformViewModel
import kotlinx.coroutines.launch
import kotlin.math.abs

private data class GuidePage(val title: String,val detail: String,val hint: String,val icon: androidx.compose.ui.graphics.vector.ImageVector)
private val guidePages = listOf(
    GuidePage("从你的学习档案开始","无需注册，设置称呼与头像，选择小学、初中、高中或大学和当前学期。多用户模式可为家人分别记录。","用户之间独立保存；关闭多用户模式不会删除其他档案。",Icons.Rounded.PersonOutline),
    GuidePage("给每次努力一个归属","先创建科目并设置满分。开启下一学期可继承同阶段科目，历史成绩仍留在原学期。","学习阶段与学期分别管理，避免混淆不同年级的记录。",Icons.Rounded.MenuBook),
    GuidePage("一科，或整场考试","单条记录分数、名称、日期和考试类型；批量录入可一次保存多科。班排、年排、区排和反思都是可选项。","填写中会保存草稿；所有行通过检查后才一起保存。",Icons.Rounded.EditNote),
    GuidePage("让记录随时可找","首页查看最近成绩和各科概览，成绩明细可搜索考试名称。轻点编辑、左滑删除，误删后可立即撤销。","不同满分独立统计，空排名不会被当作最后一名。",Icons.Rounded.ReceiptLong),
    GuidePage("看见每一步变化","查看分数与三种排名趋势、均分、最高分和优秀率。同满分多科可在一张曲线上比较，也可汇总整个学习阶段。","轻点图表查看每场考试；同一天的多次考试也各有位置。",Icons.Rounded.ShowChart),
    GuidePage("让旧记录也加入旅程","通过 Excel 导入或导出成绩。导入前查看预览和行号提示，确认科目、日期、分数、满分与分类再保存。","可先导出模板；月考、期中、期末和其他是四种考试分类。",Icons.Rounded.TableChart),
    GuidePage("让记录安心留存","完整备份保存全部用户、学期、成绩、头像、壁纸和设置。通过系统文件选择器保存或恢复，也支持来自 iOS 的完整备份。","恢复前先校验和预览；替换前保留本机恢复快照，文件未加密，请妥善保管。",Icons.Rounded.Backup),
    GuidePage("把学迹变成你的样子","设置主题色、浅色或深色外观、玻璃质感与壁纸。添加桌面成绩小组件，选择档案、学期或阶段和科目。","在设置中可随时回看本引导。无需联网登录，学习数据默认留在本机。",Icons.Rounded.Palette)
)

@Composable fun ProductGuide(onFinish: () -> Unit) {
    val pager = rememberPagerState { guidePages.size }; val scope = rememberCoroutineScope()
    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp),verticalAlignment = Alignment.CenterVertically) {
            Text("欢迎来到学迹",Modifier.weight(1f),style = MaterialTheme.typography.titleSmall)
            TextButton(onClick = onFinish,Modifier.testTag("guide.skip")) { Text("跳过") }
        }
        HorizontalPager(pager,Modifier.weight(1f)) { index ->
            val page = guidePages[index]
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp)
                .graphicsLayer { val offset = (pager.currentPage - index + pager.currentPageOffsetFraction).coerceIn(-1f,1f); rotationY = offset * 5; alpha = 1 - abs(offset) * 0.25f },verticalArrangement = Arrangement.spacedBy(28.dp)) {
                Row(Modifier.fillMaxWidth(),verticalAlignment = Alignment.CenterVertically) { StudyBrand(48.dp); Spacer(Modifier.weight(1f)); Text("${index+1} / ${guidePages.size}",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant) }
                Icon(page.icon,null,Modifier.align(Alignment.CenterHorizontally).padding(vertical = 24.dp).size(72.dp),tint = MaterialTheme.colorScheme.primary)
                Text(page.title,style = MaterialTheme.typography.headlineLarge,modifier = Modifier.semantics { heading() })
                Text(page.detail,style = MaterialTheme.typography.titleLarge,color = MaterialTheme.colorScheme.onSurfaceVariant)
                StudyPanel { Text(page.hint,style = MaterialTheme.typography.bodyMedium) }
            }
        }
        Row(Modifier.align(Alignment.CenterHorizontally),horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            repeat(guidePages.size) { index -> Box(Modifier.size(if(index == pager.currentPage) 24.dp else 8.dp,6.dp).background(if(index == pager.currentPage) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.2f),CircleShape)) }
        }
        Column(Modifier.padding(horizontal = 24.dp,vertical = 12.dp),verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(Modifier.fillMaxWidth(),verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = { scope.launch { pager.animateScrollToPage(pager.currentPage-1) } },enabled = pager.currentPage > 0) { Text("上一步") }
                Spacer(Modifier.weight(1f)); Text("${pager.currentPage+1} / ${guidePages.size}",style = MaterialTheme.typography.bodySmall)
            }
            StudyPrimary(if(pager.currentPage == guidePages.lastIndex) "开始使用" else "下一步",onClick = { if(pager.currentPage == guidePages.lastIndex) onFinish() else scope.launch { pager.animateScrollToPage(pager.currentPage+1,animationSpec = tween(350)) } },tag = "guide.next")
        }
    }
}

@Composable fun OnboardingFlow(state: PlatformState, vm: PlatformViewModel) {
    var profile by rememberSaveable { mutableStateOf(false) }
    AnimatedContent(profile,transitionSpec = { (fadeIn(tween(300)) + slideInHorizontally(tween(350)) { it/8 }).togetherWith(fadeOut(tween(150))) },label = "profile-setup") { setup ->
        if(!setup) ProductGuide { profile = true } else {
            var name by rememberSaveable { mutableStateOf("") }; var stage by rememberSaveable { mutableStateOf("high") }
            var termIndex by rememberSaveable { mutableIntStateOf(0) }; var avatar by rememberSaveable { mutableStateOf<String?>(null) }
            val terms = SchoolTerm.catalog(SchoolStage.fromWire(stage) ?: SchoolStage.HIGH)
            val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri -> if(uri != null) vm.run { val saved = vm.repository.saveImage(uri,true); kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) { avatar = saved } } }
            Column(Modifier.fillMaxSize().statusBarsPadding()) {
                Row(Modifier.fillMaxWidth(),verticalAlignment = Alignment.CenterVertically) { TextButton(onClick = { profile = false }) { Text("返回") }; Spacer(Modifier.weight(1f)) }
                StudyPage {
                    StudyBrand(72.dp)
                    Text("把努力，\n写成看得见的成长。",style = MaterialTheme.typography.headlineLarge)
                    Text("欢迎来到学迹 StudyTrack\n为你珍藏每一次考试、每一步变化。",color = MaterialTheme.colorScheme.onSurfaceVariant)
                    StudyPanel {
                        Row(Modifier.fillMaxWidth().clickable { picker.launch("image/*") },horizontalArrangement = Arrangement.spacedBy(16.dp),verticalAlignment = Alignment.CenterVertically) { StudyAvatar(name,avatar); Column { Text("设置头像"); Text("也可以稍后设置",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant) } }
                        StudyField("姓名或昵称",name,{ name = it },tag = "onboarding.name")
                        StudyPicker("学习阶段",terms[termIndex].stage.label,SchoolStage.entries.map { it.label },{ stage = SchoolStage.entries[it].wire; termIndex = 0 })
                        StudyPicker("学期",terms[termIndex].label,terms.map { it.label },{ termIndex = it })
                        StudyPrimary("开启我的学迹",onClick = { vm.run { vm.repository.createProfile(name,terms[termIndex],true,avatar) } },enabled = name.isNotBlank() && !vm.busy,tag = "onboarding.start")
                    }
                    Text("无需注册 · 本机保存 · 支持完整备份",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}
