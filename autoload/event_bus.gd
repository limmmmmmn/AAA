extends Node
## 전역 시그널 허브. 노드 간 직접 참조 금지 — 전부 여기를 경유한다.

signal gold_changed(amount: int)
signal stats_changed
signal battle_started(battle: BattleInstance)
signal battle_ended(battle: BattleInstance, result: Dictionary) # result: gold, exp, turns, one_shot
signal upgrade_purchased(upgrade: UpgradeData)
signal monster_died(monster_data: MonsterData, world_pos: Vector2)
signal party_entered_village
signal party_exited_village
signal gate_unlocked(gate_id: StringName)
signal show_toast(text: String)
signal zone_unlocked(zone_id: StringName)        # 몬스터 존 단계 해금 (A-2)
signal companion_joined(companion: CompanionData) # 동료 합류 (A-6 → PART B)
# ─── PART B (2지역) ───
signal party_hp_changed                          # 멤버별 HP 변동 (HUD가 다시 읽는다)
signal party_defeated                            # 전원 KO (B-2)
signal party_revived                             # 교회 부활 완료 (B-2)
signal region_changed(region_id: StringName)     # 지역 전환 (B-1 인프라)
signal quest_accepted(quest: QuestData)          # 의뢰 수주 (B-4)
signal quest_completed(quest: QuestData)         # 의뢰 완료 (B-4)
signal inn_rested                                # 여관 숙박 (B-3)
signal request_quest_board                       # 게시판 진입 → UI 열기 (B-4)
signal request_menu                              # HUD 메뉴 버튼 → 메뉴 열기
signal debug_mode_changed(on: bool)              # 디버그 모드 토글
# ─── v3 ───
signal screen_shake(amount: float)               # 회심의 일격 등 화면 흔들림 (§1)
signal hunt_list_changed                         # 사냥 허가 종 추가/변경 (§8)
signal tactic_retreat_triggered                  # 자동 철수 발동 (§9)
signal tactic_retreat_finished                   # 마을 귀환 완료 (§9)
